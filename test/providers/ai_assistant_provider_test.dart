import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/providers/ai_assistant_provider.dart';
import 'package:yimaflutter/database/settings_dao.dart';
import 'package:yimaflutter/database/database_helper.dart';
import 'package:yimaflutter/services/ai_health_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AiAssistantProvider provider;
  late _TestDatabaseProvider dbHelper;
  late SettingsDao settingsDao;

  setUp(() async {
    // Create an in-memory database for each test
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );

    dbHelper = _TestDatabaseProvider(db);
    settingsDao = SettingsDao(dbHelper: dbHelper);
    provider = AiAssistantProvider(settingsDao: settingsDao);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  HealthReport makeReport(int score, DateTime at) => HealthReport(
        generatedAt: at,
        currentOverview: '概览',
        cycleStats: [],
        cycleTrendSummary: '',
        symptomTrends: [],
        comparisonTrends: [],
        attentions: [],
        nextCycleSuggestions: [],
        medicalReminders: [],
        conclusion: '总结',
        healthScore: score,
      );

  group('AiAssistantProvider - report history', () {
    test('cacheReport 按时间升序追加评分历史条目', () {
      final at1 = DateTime(2026, 8, 1, 10, 30);
      final at2 = DateTime(2026, 9, 1, 10, 30);

      provider.cacheReport(makeReport(80, at1),
          modelId: 'glm-4-flash', dataVersion: 1);
      provider.cacheReport(makeReport(85, at2),
          modelId: 'ling-3.0-flash-sante:free', dataVersion: 2);

      final history = provider.reportHistory;
      expect(history, hasLength(2));
      expect(history.first.score, 80);
      expect(history.first.generatedAt, at1);
      expect(history.first.modelId, 'glm-4-flash');
      expect(history.last.score, 85);
      expect(history.last.modelId, 'ling-3.0-flash-sante:free');
    });

    test('报告历史持久化往返（写入 → 重新加载恢复）', () async {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);
      provider.cacheReport(makeReport(88, DateTime(2026, 9, 1)),
          modelId: 'glm-4-flash', dataVersion: 2);

      // 持久化是 fire-and-forget，冲刷事件队列等待落库完成
      await pumpEventQueue();

      final restored = AiAssistantProvider(settingsDao: settingsDao);
      await restored.ensureLoaded();

      expect(restored.reportHistory, hasLength(2));
      expect(restored.reportHistory.first.score, 80);
      expect(restored.reportHistory.last.score, 88);
      expect(
        restored.reportHistory.last.generatedAt,
        DateTime(2026, 9, 1),
      );
    });

    test('历史条目达到上限 30 条后丢弃最旧条目', () {
      // 写入 35 条，分数 1..35
      for (int i = 1; i <= 35; i++) {
        provider.cacheReport(makeReport(i, DateTime(2026, 1, 1).add(Duration(days: i))),
            modelId: 'glm-4-flash', dataVersion: i);
      }

      final history = provider.reportHistory;
      expect(history, hasLength(AiAssistantProvider.maxPersistedReportHistory));
      // 最旧的 5 条（分数 1~5）被丢弃
      expect(history.first.score, 6);
      expect(history.last.score, 35);
    });

    test('clearCachedReport 只清当前报告缓存，不清历史', () {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);

      provider.clearCachedReport();

      expect(provider.cachedReport, isNull);
      expect(provider.reportHistory, hasLength(1));
      expect(provider.reportHistory.first.score, 80);
    });

    test('reportHistory 返回不可变视图', () {
      provider.cacheReport(makeReport(80, DateTime(2026, 8, 1)),
          modelId: 'glm-4-flash', dataVersion: 1);

      expect(
        () => provider.reportHistory.add(
          ReportHistoryEntry(
            generatedAt: DateTime(2026, 9, 1),
            score: 90,
            modelId: 'glm-4-flash',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('AiAssistantProvider - chat sessions', () {
    ChatMessage msg(String role, String content, [DateTime? at]) => ChatMessage(
          role: role,
          content: content,
          timestamp: at ?? DateTime(2026, 9, 9, 10),
        );

    test('appendMessage 无活跃会话时自动创建会话并以首条用户消息命名', () {
      provider.appendMessage(msg('user', '我的周期规律吗？'));
      provider.appendMessage(msg('assistant', '根据数据来看…'));

      final session = provider.activeSession;
      expect(session, isNotNull);
      expect(session!.title, '我的周期规律吗？');
      expect(session.messages, hasLength(2));
      expect(provider.chatMessages, hasLength(2));
    });

    test('新建聊天保留旧会话，新消息写入新会话（数据隔离）', () {
      provider.appendMessage(
          msg('user', '问题A', DateTime(2026, 9, 1, 10)));
      provider.appendMessage(
          msg('assistant', '回答A', DateTime(2026, 9, 1, 10, 1)));
      final sessionA = provider.activeSession!;

      provider.startNewChat();
      expect(provider.activeSession, isNull);
      // 旧会话完整保留在历史列表
      expect(provider.sessions, hasLength(1));
      expect(provider.sessions.first.messages, hasLength(2));

      provider.appendMessage(
          msg('user', '问题B', DateTime(2026, 9, 9, 10)));
      provider.appendMessage(
          msg('assistant', '回答B', DateTime(2026, 9, 9, 10, 1)));
      final sessionB = provider.activeSession!;

      expect(sessionB.id, isNot(sessionA.id));
      // A 未被覆盖，B 独立成会话
      expect(sessionA.messages, hasLength(2));
      expect(sessionB.messages, hasLength(2));
      expect(provider.sessions, hasLength(2));
      // 最新会话排在最前
      expect(provider.sessions.first.id, sessionB.id);
    });

    test('当前无活跃会话时新建聊天为空操作', () {
      provider.startNewChat();
      expect(provider.activeSession, isNull);
      expect(provider.sessions, isEmpty);
    });

    test('openSession 回看历史会话的完整消息', () {
      provider.appendMessage(msg('user', '问题A'));
      provider.appendMessage(msg('assistant', '回答A'));
      final sessionA = provider.activeSession!;
      provider.startNewChat();
      provider.appendMessage(msg('user', '问题B'));
      final sessionB = provider.activeSession!;

      provider.openSession(sessionA.id);
      expect(provider.activeSession!.id, sessionA.id);
      expect(provider.chatMessages, hasLength(2));
      expect(provider.chatMessages.first.content, '问题A');
      expect(provider.chatMessages.last.content, '回答A');
      // 回看不改变其他会话内容
      expect(sessionB.messages, hasLength(1));
    });

    test('清空消息只移除当前会话，其他会话不受影响', () {
      provider.appendMessage(msg('user', '问题A'));
      provider.appendMessage(msg('assistant', '回答A'));
      provider.startNewChat();
      provider.appendMessage(msg('user', '问题B'));
      provider.appendMessage(msg('assistant', '回答B'));

      provider.clearActiveSession();

      expect(provider.activeSession, isNull);
      expect(provider.chatMessages, isEmpty);
      // 仅 B 被清除，A 完整保留
      expect(provider.sessions, hasLength(1));
      expect(provider.sessions.first.messages.first.content, '问题A');
      expect(provider.sessions.first.messages, hasLength(2));
    });

    test('清空后流式更新被安全忽略（索引越界守卫）', () {
      provider.appendMessage(msg('user', '问题A'));
      provider.appendMessage(msg('assistant', ''));

      provider.clearActiveSession();
      // 模拟迟到的流式 flush：目标会话已不在 provider 中
      expect(
        () => provider.updateMessage(
          ChatSession(
            id: 'chat_x',
            title: 't',
            messages: [],
            createdAt: DateTime(2026, 9, 9),
            updatedAt: DateTime(2026, 9, 9),
          ),
          0,
          msg('assistant', '迟到内容'),
        ),
        returnsNormally,
      );
      expect(provider.sessions, isEmpty);
    });

    test('会话数据持久化往返（写入 → 重新加载恢复，最新会话为活跃）', () async {
      provider.appendMessage(
          msg('user', '旧会话问题', DateTime(2026, 9, 1, 9)));
      provider.appendMessage(
          msg('assistant', '旧会话回答', DateTime(2026, 9, 1, 9, 1)));
      provider.persistChatHistory();
      await pumpEventQueue();

      provider.startNewChat();
      provider.appendMessage(
          msg('user', '新会话问题', DateTime(2026, 9, 9, 10)));
      provider.appendMessage(
          msg('assistant', '新会话回答', DateTime(2026, 9, 9, 10, 1)));
      provider.persistChatHistory();
      await pumpEventQueue();

      final restored = AiAssistantProvider(settingsDao: settingsDao);
      await restored.ensureLoaded();

      expect(restored.sessions, hasLength(2));
      expect(restored.sessions.first.title, '新会话问题');
      expect(restored.sessions.last.messages.first.content, '旧会话问题');
      // 启动后默认定位到最新会话
      expect(restored.activeSession?.id, restored.sessions.first.id);
      expect(restored.chatMessages.first.content, '新会话问题');
    });

    test('旧版扁平聊天数据自动迁移为单个会话并清空旧 key', () async {
      final legacy = [
        {
          'role': 'user',
          'content': '旧数据问题',
          'timestamp': DateTime(2026, 8, 30, 8).toIso8601String(),
        },
        {
          'role': 'assistant',
          'content': '旧数据回答',
          'timestamp': DateTime(2026, 8, 30, 8, 1).toIso8601String(),
        },
      ];
      await settingsDao.setValue('ai_chat_json', jsonEncode(legacy));

      final migrated = AiAssistantProvider(settingsDao: settingsDao);
      await migrated.ensureLoaded();
      await pumpEventQueue();

      expect(migrated.sessions, hasLength(1));
      expect(migrated.sessions.first.title, '旧数据问题');
      expect(migrated.sessions.first.messages, hasLength(2));
      expect(migrated.sessions.first.messages.first.content, '旧数据问题');
      expect(migrated.activeSession?.id, migrated.sessions.first.id);
      // 旧 key 已清空，避免重复迁移
      final all = await settingsDao.getAll();
      expect(all['ai_chat_json'] ?? '', '');
      // 会话已持久化到新 key
      expect(all['ai_chat_sessions_json'] ?? '', isNotEmpty);
    });

    test('单会话消息超过上限 50 条时丢弃最旧消息', () async {
      for (int i = 0; i < 55; i++) {
        provider.appendMessage(
            msg('user', '消息$i', DateTime(2026, 9, 9, 10).add(Duration(minutes: i))));
      }
      provider.persistChatHistory();
      await pumpEventQueue();

      final restored = AiAssistantProvider(settingsDao: settingsDao);
      await restored.ensureLoaded();

      expect(restored.chatMessages.length,
          AiAssistantProvider.maxMessagesPerSession);
      expect(restored.chatMessages.first.content, '消息5');
      expect(restored.chatMessages.last.content, '消息54');
    });

    test('会话数超过上限 20 个时丢弃最旧会话', () async {
      for (int i = 0; i < 25; i++) {
        provider.startNewChat();
        provider.appendMessage(
            msg('user', '会话$i', DateTime(2026, 1, 1).add(Duration(days: i))));
        provider.appendMessage(
            msg('assistant', '回答$i',
                DateTime(2026, 1, 1).add(Duration(days: i, minutes: 1))));
      }
      provider.persistChatHistory();
      await pumpEventQueue();

      final restored = AiAssistantProvider(settingsDao: settingsDao);
      await restored.ensureLoaded();

      expect(restored.sessions.length,
          AiAssistantProvider.maxPersistedChatSessions);
      // 最旧的 5 个会话（0~4）被丢弃
      expect(restored.sessions.last.title, '会话5');
      expect(restored.sessions.first.title, '会话24');
    });
  });
}

/// A test-only DatabaseProvider that wraps an in-memory database.
class _TestDatabaseProvider implements DatabaseProvider {
  final Database _db;

  _TestDatabaseProvider(this._db);

  @override
  Future<Database> get database => Future.value(_db);

  @override
  Future<void> refreshConnection() async {}

  Future<void> close() async {
    await _db.close();
  }
}
