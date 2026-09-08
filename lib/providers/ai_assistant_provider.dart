import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/settings_dao.dart';
import '../services/ai_health_service.dart';

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
    notifyListeners();
    // 异步持久化，不阻塞 UI
    _persistCachedReport();
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
  Future<void> _clearPersistedReport() async {
    try {
      await _settingsDao.setValue('ai_report_json', '');
      await _settingsDao.setValue('ai_report_data_version', '0');
      await _settingsDao.setValue('ai_report_model_id', '');
    } catch (e) {
      debugPrint('Error clearing persisted AI report: $e');
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
