import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_strings.dart';
import '../database/settings_dao.dart';
import '../services/ai_health_service.dart';

/// 单条 AI 报告历史索引（1.34.0 评分趋势数据源）。
///
/// 只存趋势图所需的最小字段（评分/生成时间/模型），不缓存完整报告
/// 正文——完整报告仍以 `ai_report_json` 单条缓存为准，历史列表用于
/// 观察评分随周期的变化趋势。
class ReportHistoryEntry {
  final DateTime generatedAt;

  /// 健康评分（0-100）。
  final int score;

  /// 生成报告时使用的模型 ID。
  final String modelId;

  const ReportHistoryEntry({
    required this.generatedAt,
    required this.score,
    required this.modelId,
  });

  factory ReportHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReportHistoryEntry(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      modelId: json['modelId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'score': score,
        'modelId': modelId,
      };
}

/// 单个聊天会话（1.36.0 会话化改造）。
///
/// 每次「新建聊天」产生一个独立会话，会话之间消息完全隔离；
/// 「清空消息」只作用于当前会话；历史会话通过 [openSession] 回看。
class ChatSession {
  final String id;

  /// 会话标题：取本会话第一条用户消息截断生成。
  String title;

  /// 本会话的全部消息（按时间升序，最后一条最新）。
  final List<ChatMessage> messages;

  final DateTime createdAt;
  DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList()
        : <ChatMessage>[];
    return ChatSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      messages: messages,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// AI 助手缓存 Provider。
///
/// 从 [PeriodProvider] 迁出的 AI 职责（P1-5）：
/// - AI 健康报告缓存（内存 + SQLite 持久化，key：`ai_report_json` 等）
/// - AI 问答聊天会话（内存 + SQLite 持久化，key：`ai_chat_sessions_json`，
///   1.36.0 起会话化存储，旧扁平格式 `ai_chat_json` 自动迁移）
///
/// 拆分动机：聊天/报告状态变更不再耦合经期数据监听链，AI 缓存可独立
/// 单测；本 Provider 不依赖 [PeriodProvider] —— 报告过期判断所需的
/// dataVersion 由调用方以参数传入，保持构造可独立完成（测试友好）。
class AiAssistantProvider with ChangeNotifier {
  final SettingsDao _settingsDao;

  /// Allows injecting a [SettingsDao] for testing; defaults to the singleton.
  AiAssistantProvider({SettingsDao? settingsDao})
      : _settingsDao = settingsDao ?? SettingsDao();

  // ─── AI 报告缓存（跨页面持久化）──────────────────────────────
  /// 缓存上次生成的 AI 健康报告。退出 AI 助手页面后仍保留。
  HealthReport? _cachedReport;

  /// 报告生成时的 dataVersion，用于判断经期数据是否已更新。
  int _reportDataVersion = 0;

  /// 报告生成时使用的模型 ID，用于判断是否需要重新生成。
  String _reportModelId = '';

  // ─── 报告历史（评分趋势，1.34.0）────────────────────────────
  /// 历次报告的评分索引，按生成时间升序追加（最后一条最新）。
  final List<ReportHistoryEntry> _reportHistory = [];

  /// 报告历史持久化保留上限：只保留最近 [maxPersistedReportHistory]
  /// 条，防止 `ai_report_history_json` 无限膨胀。
  static const int maxPersistedReportHistory = 30;

  // ─── 聊天会话（跨页面持久化，1.36.0 会话化）──────────────────
  /// 全部聊天会话，按 updatedAt 降序（最新会话在前）。
  final List<ChatSession> _sessions = [];

  /// 当前活跃会话 id；null 表示处于「新建聊天」空状态。
  String? _activeSessionId;

  /// 聊天会话持久化保留上限：只保留最近 [maxPersistedChatSessions] 个
  /// 会话，防止 `ai_chat_sessions_json` 无限膨胀。
  static const int maxPersistedChatSessions = 20;

  /// 单个会话内消息保留上限（写入持久化时截断最旧消息）。
  static const int maxMessagesPerSession = 50;

  /// 首次 [ensureLoaded] 时创建的加载任务；并发调用共享同一份 Future。
  Future<void>? _loadFuture;

  // ─── 流式回放（D2 自 UI 层下沉）──────────────────────────────
  // SSE chunk 之间通常只隔几毫秒，逐 chunk notifyListeners 会以 chunk
  // 频率重建整屏并让 MarkdownBody 全文重解析（P0-1 热点）。将 UI 刷新
  // 合并为最多 ~12.5 次/秒：距上次刷新 ≥80ms 立即刷新，否则安排
  // trailing 补刷。回放节奏此前沉在 AI 屏 State 的定时器里（不可单测），
  // 1.37.0 起移入本 Provider —— 回放参数调整不再触碰 UI 文件。
  final StringBuffer _streamBuffer = StringBuffer();

  /// 正在流式输出的会话 id：流式写入始终绑定发起时的会话，
  /// 中途新建/切换会话不会串写其他会话（数据隔离）。
  String? _streamingSessionId;

  /// 流式渲染节流窗口。
  static const Duration streamFlushInterval = Duration(milliseconds: 80);

  /// 上一次把流式内容刷新到 UI 的时刻（节流基准）。
  DateTime? _lastFlushAt;

  /// trailing 补刷定时器：chunk 到达过密时延迟到节流窗口边界一次性刷新，
  /// 保证窗口内累积的内容最终不丢。
  Timer? _flushTimer;

  /// 当前流式输出绑定的会话 id（供 UI 判断"最后一条 AI 消息是否正在
  /// 流式输出"）。非流式期间为 null。
  String? get streamingSessionId => _streamingSessionId;

  // ─── getter ──────────────────────────────────────────────────
  /// 获取缓存的 AI 健康报告（可能为 null）。
  HealthReport? get cachedReport => _cachedReport;

  /// 报告生成时的 dataVersion。
  int get reportDataVersion => _reportDataVersion;

  /// 报告生成时使用的模型 ID。
  String get reportModelId => _reportModelId;

  /// 获取当前活跃会话（可能为 null，表示新建聊天空状态）。
  ChatSession? get activeSession {
    if (_activeSessionId == null) return null;
    for (final s in _sessions) {
      if (s.id == _activeSessionId) return s;
    }
    return null;
  }

  /// 当前活跃会话的消息列表（无活跃会话时为空列表）。
  ///
  /// 直接引用会话内部列表（与旧 chatHistory 语义一致），供 UI 渲染；
  /// 结构性修改请走本 Provider 的方法，保证排序与持久化正确。
  List<ChatMessage> get chatMessages =>
      activeSession?.messages ?? const [];

  /// 全部历史会话（只读视图，updatedAt 降序，最新在前）。
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  /// 是否存在当前会话（用于「清空消息」入口的显隐）。
  bool get hasActiveSession => activeSession != null;

  /// 历次报告评分索引（只读视图，按时间升序，最后一条最新）。
  List<ReportHistoryEntry> get reportHistory =>
      List.unmodifiable(_reportHistory);

  /// 确保缓存的 AI 报告/聊天历史已从 DB 加载完成（重复调用安全）。
  ///
  /// 模式仿 SettingsProvider.ensureLoaded：ChangeNotifierProvider 默认懒
  /// 创建，任何读取缓存值的路径都应先 await 本方法。
  Future<void> ensureLoaded() => _loadFuture ??= _performLoad();

  /// 从 SQLite 加载 AI 报告与聊天历史。
  ///
  /// 同源单查询：三个报告 key 与一个聊天 key 一次 getAll() 取回，
  /// 与 SettingsProvider.loadSettings 的批量加载策略一致。
  Future<void> _performLoad() async {
    try {
      final all = await _settingsDao.getAll();

      // ── AI 报告缓存 ──
      final reportJson = all['ai_report_json'];
      if (reportJson != null && reportJson.isNotEmpty) {
        final json = jsonDecode(reportJson) as Map<String, dynamic>;
        _cachedReport = HealthReport.fromJson(json);
        _reportDataVersion =
            int.tryParse(all['ai_report_data_version'] ?? '0') ?? 0;
        _reportModelId = all['ai_report_model_id'] ?? '';
      }

      // ── 报告历史（评分趋势，1.34.0）──
      final historyJson = all['ai_report_history_json'];
      if (historyJson != null && historyJson.isNotEmpty) {
        final decoded = jsonDecode(historyJson);
        if (decoded is List) {
          _reportHistory.addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(ReportHistoryEntry.fromJson),
          );
          // 防御：持久化数据异常超限时丢弃最旧的
          if (_reportHistory.length > maxPersistedReportHistory) {
            _reportHistory.removeRange(
                0, _reportHistory.length - maxPersistedReportHistory);
          }
        }
      }

      // ── 聊天会话持久化（1.36.0 会话化）──
      final chatJson = all['ai_chat_sessions_json'];
      var migratedLegacy = false;
      if (chatJson != null && chatJson.isNotEmpty) {
        final decoded = jsonDecode(chatJson);
        if (decoded is List) {
          _sessions.addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(ChatSession.fromJson),
          );
          // 防御：持久化数据异常超限时丢弃最旧的会话
          if (_sessions.length > maxPersistedChatSessions) {
            _sessions.removeRange(
                0, _sessions.length - maxPersistedChatSessions);
          }
          for (final s in _sessions) {
            if (s.messages.length > maxMessagesPerSession) {
              s.messages.removeRange(
                  0, s.messages.length - maxMessagesPerSession);
            }
          }
        }
      } else {
        // ── 旧版扁平聊天数据（ai_chat_json）一次性迁移为单个会话 ──
        migratedLegacy = _migrateLegacyChat(all['ai_chat_json']);
      }
      _sortSessions();
      // 启动后默认定位到最近的会话（延续旧版"重启可见上次对话"行为）
      if (_sessions.isNotEmpty && activeSession == null) {
        _activeSessionId = _sessions.first.id;
      }
      if (migratedLegacy) {
        // 迁移成功后清空旧 key，避免下次重复迁移
        _settingsDao.setValue('ai_chat_json', '');
      }
    } catch (e) {
      debugPrint('Error loading AI assistant cache: $e');
    }
  }

  /// 保存 AI 健康报告到缓存，并持久化到 SQLite。
  ///
  /// [dataVersion] 由调用方传入报告缓存时刻的 PeriodProvider.dataVersion
  /// 快照（本 Provider 不持有经期数据，保持独立可测）。
  void cacheReport(
    HealthReport report, {
    required String modelId,
    required int dataVersion,
  }) {
    _cachedReport = report;
    _reportDataVersion = dataVersion;
    _reportModelId = modelId;
    // 追加评分历史（趋势图数据源）。同一次生成不会重复调用本方法，
    // 不做内容级去重；上限截断丢弃最旧条目。
    _reportHistory.add(ReportHistoryEntry(
      generatedAt: report.generatedAt,
      score: report.healthScore,
      modelId: modelId,
    ));
    if (_reportHistory.length > maxPersistedReportHistory) {
      _reportHistory.removeRange(
          0, _reportHistory.length - maxPersistedReportHistory);
    }
    notifyListeners();
    // 异步持久化，不阻塞 UI
    _persistCachedReport();
    _persistReportHistory();
  }

  /// 清除缓存的 AI 健康报告（如用户手动刷新或数据变更后）。
  void clearCachedReport() {
    _cachedReport = null;
    _reportDataVersion = 0;
    _reportModelId = '';
    notifyListeners();
    // 异步清除持久化（失败静默，与 [_persistCachedReport] 策略一致）
    _clearPersistedReport();
  }

  /// 判断自上次报告生成后经期数据是否已更新。
  ///
  /// [currentDataVersion] 由调用方传入当前的 PeriodProvider.dataVersion。
  bool isReportDataStale(int currentDataVersion) =>
      _reportDataVersion != 0 && _reportDataVersion != currentDataVersion;

  /// 将缓存的 AI 报告持久化到 SQLite。
  Future<void> _persistCachedReport() async {
    try {
      if (_cachedReport == null) return;
      final jsonStr = jsonEncode(_cachedReport!.toJson());
      await _settingsDao.setValue('ai_report_json', jsonStr);
      await _settingsDao.setValue(
          'ai_report_data_version', _reportDataVersion.toString());
      await _settingsDao.setValue('ai_report_model_id', _reportModelId);
    } catch (e) {
      debugPrint('Error persisting AI report: $e');
    }
  }

  /// 清除 SQLite 中持久化的 AI 报告。
  ///
  /// 注意：只清当前报告缓存，不清 [_reportHistory]——历史是趋势数据，
  /// 重新生成报告不应抹掉评分变化轨迹。
  Future<void> _clearPersistedReport() async {
    try {
      await _settingsDao.setValue('ai_report_json', '');
      await _settingsDao.setValue('ai_report_data_version', '0');
      await _settingsDao.setValue('ai_report_model_id', '');
    } catch (e) {
      debugPrint('Error clearing persisted AI report: $e');
    }
  }

  /// 将报告评分历史持久化到 SQLite（只保留最近 [maxPersistedReportHistory] 条）。
  Future<void> _persistReportHistory() async {
    try {
      if (_reportHistory.isEmpty) return;
      final jsonStr = jsonEncode(
        _reportHistory.map((e) => e.toJson()).toList(),
      );
      await _settingsDao.setValue('ai_report_history_json', jsonStr);
    } catch (e) {
      debugPrint('Error persisting report history: $e');
    }
  }

  // ─── 流式回放控制（D2 下沉的公开 API）────────────────────────

  /// 一轮流式输出开始：绑定目标会话、清空缓冲、重置节流基准
  /// （确保首个 chunk 立即上屏）。
  void beginChatStream(ChatSession session) {
    _streamingSessionId = session.id;
    _streamBuffer.clear();
    _lastFlushAt = null;
    _cancelFlushTimer();
  }

  /// SSE chunk 到达：写入缓冲并按节流策略合并刷新 UI。
  void onStreamChunk(ChatSession session, String chunk) {
    _streamBuffer.write(chunk);
    _scheduleStreamFlush(session);
  }

  /// 流正常结束：取消未触发的 trailing 补刷并做最终 flush，
  /// 把节流窗口内累积的剩余内容完整落进会话，随后解除会话绑定。
  void finishChatStream(ChatSession session) {
    _cancelFlushTimer();
    _flushStreamingBuffer(session);
    _streamingSessionId = null;
  }

  /// 流异常结束：取消补刷定时器（避免 timer 随后用无错误标记的内容
  /// 覆盖错误提示），保留已收到的部分内容并追加错误标记；未收到任何
  /// 内容时整条替换为错误提示。随后解除会话绑定。
  void abortChatStream(ChatSession session, String errorMsg) {
    _cancelFlushTimer();
    if (session.messages.isNotEmpty) {
      if (_streamBuffer.isNotEmpty) {
        updateMessage(
          session,
          session.messages.length - 1,
          ChatMessage(
            role: 'assistant',
            content: '${_streamBuffer.toString()}\n\n⚠️ $errorMsg',
            timestamp: DateTime.now(),
          ),
        );
      } else {
        updateMessage(
          session,
          session.messages.length - 1,
          ChatMessage(
            role: 'assistant',
            content: '${AppStrings.aiChatFailedPrefix}$errorMsg',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    _streamingSessionId = null;
  }

  /// 立即将流式缓冲刷新到 UI：更新流式目标会话的最后一条 AI 消息。
  ///
  /// 写入始终绑定发起流式时的 [session]；若该会话已被清空（消息列表
  /// 为空），丢弃本次内容——用户主动清空优先于迟到的流数据。
  void _flushStreamingBuffer(ChatSession session) {
    _flushTimer?.cancel();
    _flushTimer = null;
    _lastFlushAt = DateTime.now();
    if (session.messages.isEmpty) return;
    updateMessage(
      session,
      session.messages.length - 1,
      ChatMessage(
        role: 'assistant',
        content: _streamBuffer.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// 节流调度：距上次 UI 刷新 ≥[streamFlushInterval] 则立即刷新；
  /// 否则只安排一次 trailing 补刷（已有 pending 时跳过，窗口到点会把
  /// 当时 buffer 的全部累积内容一次性刷出）。
  void _scheduleStreamFlush(ChatSession session) {
    final now = DateTime.now();
    final last = _lastFlushAt;
    if (last == null || now.difference(last) >= streamFlushInterval) {
      _flushStreamingBuffer(session);
      return;
    }
    _flushTimer ??= Timer(
      streamFlushInterval - now.difference(last),
      () => _flushStreamingBuffer(session),
    );
  }

  /// 取消未触发的 trailing 补刷定时器。
  void _cancelFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  // ─── 聊天会话操作（1.36.0）───────────────────────────────────

  /// 按 updatedAt 降序排序（最新会话在前），updatedAt 相同时以
  /// createdAt 兜底，保证快速连续创建的会话排序确定。
  void _sortSessions() {
    _sessions.sort((a, b) {
      final byUpdate = b.updatedAt.compareTo(a.updatedAt);
      if (byUpdate != 0) return byUpdate;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  /// 由首条用户消息生成会话标题（压缩空白、最多 20 字符）。
  String _deriveTitle(String firstUserMessage) {
    final compact = firstUserMessage
        .replaceAll('\n', ' ')
        .trim();
    if (compact.isEmpty) return '新对话';
    return compact.length <= 20 ? compact : '${compact.substring(0, 20)}…';
  }

  String _newSessionId() =>
      'chat_${DateTime.now().microsecondsSinceEpoch}_${_sessionSeq++}';

  /// 会话 id 自增序号：与时间戳组合，保证快速连续创建时不重复。
  int _sessionSeq = 0;

  /// 「新建聊天」：结束当前会话（保留为历史），回到空状态。
  ///
  /// 当前会话的消息完整保留在历史列表中，不被覆盖；再次发消息时
  /// 才会创建新的会话。当前无活跃会话时为空操作。
  void startNewChat() {
    if (_activeSessionId == null) return;
    _activeSessionId = null;
    notifyListeners();
  }

  /// 「清空消息」：清除当前会话的全部消息内容。
  ///
  /// 只移除当前活跃会话，其他历史会话不受影响；清空后回到空状态。
  void clearActiveSession() {
    final session = activeSession;
    if (session == null) return;
    // 先清内容再移除：流式输出持有该会话引用时，isEmpty 守卫可让
    // 迟到的流内容被安全丢弃，不会写回已清空的会话。
    session.messages.clear();
    _sessions.remove(session);
    _activeSessionId = null;
    notifyListeners();
    _persistSessions();
  }

  /// 打开一个历史会话（回看完整消息，可继续在该会话中追问）。
  void openSession(String sessionId) {
    final exists = _sessions.any((s) => s.id == sessionId);
    if (!exists) return;
    if (_activeSessionId == sessionId) return;
    _activeSessionId = sessionId;
    notifyListeners();
  }

  /// 向当前会话追加一条消息；无活跃会话时自动创建新会话
  /// （标题取首条用户消息）。只在内存中生效，持久化由
  /// [persistChatHistory] 在整轮问答结束时统一执行。
  void appendMessage(ChatMessage msg) {
    var session = activeSession;
    if (session == null) {
      session = ChatSession(
        id: _newSessionId(),
        title: msg.role == 'user' ? _deriveTitle(msg.content) : '新对话',
        messages: [],
        createdAt: msg.timestamp,
        updatedAt: msg.timestamp,
      );
      _sessions.add(session);
      _activeSessionId = session.id;
    }
    session.messages.add(msg);
    // 单会话消息上限：丢弃最旧消息（与旧版全局 50 条上限策略一致）
    if (session.messages.length > maxMessagesPerSession) {
      session.messages.removeAt(0);
    }
    // 会话有新消息落定 → 以该消息时间戳更新活跃时间（确定性排序）
    session.updatedAt = msg.timestamp;
    _sortSessions();
    notifyListeners();
  }

  /// 原地更新指定会话中的一条消息（流式输出 flush 用）。
  ///
  /// 索引越界（如会话已被清空）时静默忽略，保证流式写入不崩溃；
  /// 不更新 updatedAt（回看历史不改变会话排序）。
  void updateMessage(ChatSession session, int index, ChatMessage msg) {
    if (index < 0 || index >= session.messages.length) return;
    session.messages[index] = msg;
    notifyListeners();
  }

  /// 在每轮问答落库后调用（正常结束或出错落库时），把会话数据持久化。
  ///
  /// 流式输出过程中【不】调用本方法——逐 chunk 写库会造成高频 IO；
  /// 只在整轮回答完成（含错误标记）时写入一次。
  /// fire-and-forget：持久化失败不影响 UI。
  void persistChatHistory() {
    _persistSessions();
  }

  /// 将会话数据持久化到 SQLite。
  ///
  /// 上限策略：最近 [maxPersistedChatSessions] 个会话，每个会话内
  /// 最近 [maxMessagesPerSession] 条消息。
  Future<void> _persistSessions() async {
    try {
      if (_sessions.isEmpty) {
        await _settingsDao.setValue('ai_chat_sessions_json', '');
        return;
      }
      final sessionsSnapshot = _sessions.length > maxPersistedChatSessions
          ? _sessions.sublist(0, maxPersistedChatSessions)
          : _sessions;
      final jsonStr = jsonEncode(
        sessionsSnapshot.map((s) => s.toJson()).toList(),
      );
      await _settingsDao.setValue('ai_chat_sessions_json', jsonStr);
    } catch (e) {
      debugPrint('Error persisting chat sessions: $e');
    }
  }

  /// 尝试把旧版扁平聊天数据（`ai_chat_json`）迁移为一个会话。
  ///
  /// 返回是否发生了迁移；解析失败返回 false（旧数据原样保留）。
  bool _migrateLegacyChat(String? legacyJson) {
    if (legacyJson == null || legacyJson.isEmpty) return false;
    try {
      final decoded = jsonDecode(legacyJson);
      if (decoded is! List) return false;
      final messages = decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      if (messages.isEmpty) return false;
      if (messages.length > maxMessagesPerSession) {
        messages.removeRange(0, messages.length - maxMessagesPerSession);
      }
      final firstUser = messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => messages.first,
      );
      final session = ChatSession(
        id: _newSessionId(),
        title: _deriveTitle(firstUser.content),
        messages: messages,
        createdAt: messages.first.timestamp,
        updatedAt: messages.last.timestamp,
      );
      _sessions.add(session);
      _activeSessionId = session.id;
      _persistSessions();
      return true;
    } catch (e) {
      debugPrint('Error migrating legacy chat: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // 取消流式 trailing 补刷定时器，避免 dispose 后回调访问已释放状态
    _cancelFlushTimer();
    super.dispose();
  }
}
