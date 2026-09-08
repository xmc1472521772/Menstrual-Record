import 'dart:convert';

import 'package:flutter/foundation.dart';

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

/// AI 助手缓存 Provider。
///
/// 从 [PeriodProvider] 迁出的 AI 职责（P1-5）：
/// - AI 健康报告缓存（内存 + SQLite 持久化，key：`ai_report_json` 等）
/// - AI 问答聊天历史（内存 + SQLite 持久化，key：`ai_chat_json`，P1-8）
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

  // ─── 聊天历史（跨页面持久化）─────────────────────────────────
  /// 缓存 AI 问答的聊天历史。退出 AI 助手页面后仍保留。
  final List<ChatMessage> _chatHistory = [];

  /// 聊天历史持久化保留上限：只保留最近 [maxPersistedChatMessages] 条，
  /// 防止长期使用后 `ai_chat_json` 无限膨胀。
  static const int maxPersistedChatMessages = 50;

  /// 首次 [ensureLoaded] 时创建的加载任务；并发调用共享同一份 Future。
  Future<void>? _loadFuture;

  // ─── getter ──────────────────────────────────────────────────
  /// 获取缓存的 AI 健康报告（可能为 null）。
  HealthReport? get cachedReport => _cachedReport;

  /// 报告生成时的 dataVersion。
  int get reportDataVersion => _reportDataVersion;

  /// 报告生成时使用的模型 ID。
  String get reportModelId => _reportModelId;

  /// 获取缓存的 AI 聊天历史（可变引用，UI 可直接操作）。
  List<ChatMessage> get chatHistory => _chatHistory;

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

      // ── 聊天历史持久化（P1-8）──
      final chatJson = all['ai_chat_json'];
      if (chatJson != null && chatJson.isNotEmpty) {
        final decoded = jsonDecode(chatJson);
        if (decoded is List) {
          _chatHistory.addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(ChatMessage.fromJson),
          );
          // 防御：持久化数据异常超限时截断到上限
          if (_chatHistory.length > maxPersistedChatMessages) {
            _chatHistory.removeRange(
                0, _chatHistory.length - maxPersistedChatMessages);
          }
        }
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

  // ─── 聊天历史 ────────────────────────────────────────────────

  /// 清除聊天历史（内存 + 持久化同步清除）。
  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
    _clearPersistedChat();
  }

  /// 在每轮问答落库后调用（正常结束或出错落库时），把聊天历史持久化。
  ///
  /// 流式输出过程中【不】调用本方法——逐 chunk 写库会造成高频 IO；
  /// 只在整轮回答完成（含错误标记）时写入一次。
  /// fire-and-forget：持久化失败不影响 UI。
  void persistChatHistory() {
    _persistChatHistory();
  }

  /// 将聊天历史持久化到 SQLite（只保留最近 [maxPersistedChatMessages] 条）。
  Future<void> _persistChatHistory() async {
    try {
      if (_chatHistory.isEmpty) return;
      final persisted = _chatHistory.length > maxPersistedChatMessages
          ? _chatHistory.sublist(
              _chatHistory.length - maxPersistedChatMessages)
          : _chatHistory;
      final jsonStr =
          jsonEncode(persisted.map((m) => m.toJson()).toList());
      await _settingsDao.setValue('ai_chat_json', jsonStr);
    } catch (e) {
      debugPrint('Error persisting chat history: $e');
    }
  }

  /// 清除 SQLite 中持久化的聊天历史。
  Future<void> _clearPersistedChat() async {
    try {
      await _settingsDao.setValue('ai_chat_json', '');
    } catch (e) {
      debugPrint('Error clearing persisted chat history: $e');
    }
  }
}
