/// 响应式断点常量（B1：宽屏形态预留）。
///
/// 当前 App 仅针对竖屏手机打磨（4 tab + 单列滚动布局），无真机平板
/// 验证条件，故本文件先固化断点约定供后续宽屏布局（如首页双栏、
/// 统计概览圆环自适应换行）渐进接入：
/// - 逻辑宽度 < [wide]：手机单列形态（现状，勿在未验证前改动）；
/// - ≥ [wide]：平板/折叠屏展开态，可启用双栏等增强布局；
/// - ≥ [desktop]：横屏大屏/桌面窗口，可进一步分栏。
///
/// 使用方式：`LayoutBuilder` 或 `MediaQuery.sizeOf(context).width` 与
/// 断点比较，禁止在页面内散写 600/840 等裸数字。
class AppBreakpoints {
  AppBreakpoints._();

  /// 平板/折叠屏展开态下限（dp）。
  static const double wide = 600;

  /// 横屏大屏 / 桌面窗口下限（dp）。
  static const double desktop = 840;
}
