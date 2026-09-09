/// 动效时长 token（P1-6）。
///
/// 收敛项目里散落的字面量时长（实测 6 种：150 / 200 / 280 / 300 /
/// 600 / 800 / 1200），统一为 4 档可感知节奏，让同类交互时长一致：
/// - [fast] 微交互（图标切换、输入框聚焦反馈）
/// - [base] 通用过渡（滑块、AnimatedSize、flow 选中态）
/// - [slow] 导航滑块、日历翻页、月份标题淡入
/// - [page] 页面级转场（启动页、多选日历回位）
///
/// 注：AI 流式光标闪烁（600ms）、启动页 logo 淡入（800ms）、启动页
/// 停留（1200ms）属于各自领域特有的节奏，不在通用档位内，保留原字面量。
class AppMotion {
  AppMotion._();

  /// 微交互。
  static const Duration fast = Duration(milliseconds: 150);

  /// 通用过渡。
  static const Duration base = Duration(milliseconds: 200);

  /// 导航滑块 / 日历翻页。
  static const Duration slow = Duration(milliseconds: 280);

  /// 页面级转场。
  static const Duration page = Duration(milliseconds: 300);
}
