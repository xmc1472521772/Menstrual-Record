# 交付概览：Ling-3.0 流式优化 + Key 编译注入 APK（1.36.1+115）

## 诊断结论（curl 带时间戳抓真实 SSE）
- 上游**是真流式**：96 个正文 chunk 从 0s 滴流到 70.8s，每块仅 1~3 字符（免费通道生成速度 ~2 字/秒）；无 reasoning 字段（`reasoning:{enabled:false,exclude:true}` 生效）、无 `<think>` 内嵌。
- "内容一次性全部出现"的根因：OpenRouter 免费通道按请求路由到不同上游，**部分上游把整段回答攒在缓冲里，用单个超大 delta 一次性吐出**；原代码直接透传，正文瞬间砸屏。
- 附带体验问题：免费通道首响应与生成均慢，原"正在思考…"无任何进度反馈。

## 修复内容
| 文件 | 变更 |
|---|---|
| lib/services/ai_health_service.dart | 新增 `revealContentChunk()`：delta ≤120 字透传（真流式不受影响）；>120 字按打字机节奏平滑放行（基准 200 字/秒，超长块自动提速，单块最长 ~5.4s）。两处 yield 点接入 |
| lib/screens/ai_assistant_screen.dart | 思考指示器升级为 `_ThinkingIndicator`：等待超 3 秒显示"正在思考… Ns"实时秒数 |
| test/services/ai_health_service_test.dart | 新增 3 条平滑回放测试（小 delta 透传 / 大 delta 拆块不丢字 / 超长块 6s 内放完） |
| pubspec.yaml | 1.36.0+114 → 1.36.1+115 |

## API Key 编译注入（已构建 release APK）
- 构建命令：`flutter build apk --release --dart-define=GLM_API_KEY=*** --dart-define=OPENROUTER_API_KEY=***`
- 两个 key 均已先 curl 验证有效（GLM 返回 ok / OpenRouter 流式 200）
- **key 值不落代码 / git / memory，仅存在于构建命令行**，已编译进内核快照
- 产物：`build/app/outputs/flutter-apk/app-release.apk`（63.5MB，debug 签名可直接安装）

## 验证
- `flutter analyze`：0 issue
- `flutter test`：156/156 通过（含 3 条新增平滑回放测试）
- `flutter build apk --release`：构建成功
