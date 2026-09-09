import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/services/ai_health_service.dart';

void main() {
  /// 构造一份字段齐全的合法报告 JSON 文本。
  String validReportJson({int score = 80}) {
    return '''
{
  "healthScore": $score,
  "currentOverview": "本次经期5天，经量正常。",
  "cycleStats": [
    {"label": "平均周期", "value": "28天"},
    {"label": "最短周期", "value": "26天"},
    {"label": "最长周期", "value": "30天"},
    {"label": "波动范围", "value": "4天"},
    {"label": "平均经期", "value": "5天"},
    {"label": "规律性", "value": "非常规律"}
  ],
  "cycleTrendSummary": "周期整体稳定。",
  "symptomTrends": [
    {"name": "痛经", "status": "偶尔出现", "detail": "仅最近一次记录"}
  ],
  "comparisonTrends": [
    {"name": "周期长度", "status": "稳定", "detail": "与过去相比无明显变化"}
  ],
  "attentions": [
    {"title": "痛经", "detail": "可继续观察", "evidence": "近期1次记录"}
  ],
  "nextCycleSuggestions": [
    {"title": "规律记录", "detail": "建议继续每日记录经量"}
  ],
  "medicalReminders": [
    {"condition": "剧烈腹痛", "detail": "如持续出现请就医", "userMatched": false}
  ],
  "conclusion": "整体平稳，建议持续记录。"
}
''';
  }

  group('AI 报告响应解析（Ling-3.0 兼容性加固）', () {
    test('纯 JSON 文本直接解析成功', () {
      final report = AIHealthService.parseReportResponse(validReportJson());
      expect(report.healthScore, 80);
      expect(report.currentOverview, contains('5天'));
      expect(report.cycleStats.length, 6);
      expect(report.symptomTrends.first.name, '痛经');
      expect(report.medicalReminders.first.userMatched, false);
    });

    test('```json 代码块包裹的响应解析成功', () {
      final content = '以下是分析结果：\n```json\n${validReportJson()}\n```\n希望有帮助';
      final report = AIHealthService.parseReportResponse(content);
      expect(report.healthScore, 80);
    });

    test('<think> 思考标签被剥离（思考内含大括号不干扰提取）', () {
      // 模拟推理模型在正文中内嵌思考：思考里含大括号与类 JSON 片段
      final content = '<think>\n用户数据周期28天，先算均值 {"a": 1}。\n'
          '需要输出 JSON。\n</think>\n${validReportJson(score: 85)}';
      final report = AIHealthService.parseReportResponse(content);
      expect(report.healthScore, 85);
      expect(report.conclusion, contains('平稳'));
    });

    test('<think> 思考标签包裹 ```json 代码块的响应解析成功', () {
      final content = '<think>让我组织一下报告结构。</think>\n'
          '```json\n${validReportJson(score: 90)}\n```';
      final report = AIHealthService.parseReportResponse(content);
      expect(report.healthScore, 90);
    });

    test('未闭合的 <think> 标签（截断输出）不导致误提取', () {
      // 整个输出只有思考没有正文 → 无法提取 JSON → 应抛可重试异常
      const content = '<think>用户数据周期28天，计算 {"a": 1}';
      expect(
        () => AIHealthService.parseReportResponse(content),
        throwsA(
          isA<AiServiceException>()
              .having((e) => e.retryable, 'retryable', true),
        ),
      );
    });

    test('单引号与尾逗号等常见格式问题被自动修复', () {
      // 模拟模型输出：单引号键值 + 尾逗号
      const content = "{'healthScore': 70, 'currentOverview': '经期规律。', "
          "'cycleStats': [{'label': '平均周期', 'value': '28天',},], "
          "'cycleTrendSummary': '稳定。', 'symptomTrends': [], "
          "'comparisonTrends': [], 'attentions': [], "
          "'nextCycleSuggestions': [], 'medicalReminders': [], "
          "'conclusion': '良好。'}";
      final report = AIHealthService.parseReportResponse(content);
      expect(report.healthScore, 70);
      expect(report.cycleStats.first.label, '平均周期');
    });

    test('无任何 JSON 内容时抛出可重试异常', () {
      const content = '抱歉，我无法生成报告。';
      expect(
        () => AIHealthService.parseReportResponse(content),
        throwsA(
          isA<AiServiceException>()
              .having((e) => e.retryable, 'retryable', true)
              .having((e) => e.message, 'message', contains('格式不正确')),
        ),
      );
    });

    test('Ling 模型配置使用更大的输出预算', () {
      final ling = AIHealthService.configFor('ling-3.0-flash-sante');
      final glm = AIHealthService.configFor('glm-4-flash');
      // Ling-3.0 为推理模型，思考与正文共享预算，需要更大 max_tokens
      expect(ling.maxOutputTokens, greaterThan(glm.maxOutputTokens));
      expect(glm.maxOutputTokens, 4096); // GLM-4-Flash 上限内
    });
  });

  group('流式内容平滑放行（大 delta 打字机回放）', () {
    test('token 级小 delta 直接透传（单块产出，无节流延迟）', () async {
      final sw = Stopwatch()..start();
      final chunks = await AIHealthService.revealContentChunk('月经周期正常').toList();
      sw.stop();

      expect(chunks, ['月经周期正常']); // 原样单块透传
      expect(sw.elapsedMilliseconds, lessThan(500)); // 未走打字机节奏
    });

    test('超大 delta 平滑放行：多块产出、内容完整、有节奏延迟', () async {
      final big = '这是一段被上游攒在缓冲里一次性吐出的超长回答。' * 8; // 336 字
      final sw = Stopwatch()..start();
      final chunks = await AIHealthService.revealContentChunk(big).toList();
      sw.stop();

      expect(chunks.length, greaterThan(3)); // 拆成多块
      expect(chunks.join(), big); // 内容不丢失
      // 336 字 @ 200字/秒 ≈ 1.7s；宽边界 [600ms, 5s) 防止 CI 抖动误报
      expect(sw.elapsedMilliseconds, greaterThan(600));
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('超大 delta 自动提速：单块放行时长不超过 6 秒', () async {
      final big = '字' * 3000; // 3000 字若按基准 200 字/秒需 15s，必须提速
      final sw = Stopwatch()..start();
      final chunks = await AIHealthService.revealContentChunk(big).toList();
      sw.stop();

      expect(chunks.join(), big);
      expect(sw.elapsedMilliseconds, lessThan(6000));
    });
  });
}
