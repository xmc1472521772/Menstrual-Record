import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:yimaflutter/constants/app_colors.dart';
import 'package:yimaflutter/constants/app_theme.dart';
import 'package:yimaflutter/widgets/common_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('common_widgets（E3 基础组件测试）', () {
    testWidgets('SectionCard：渲染标题与内容（A2 统一后的表面层级）',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SectionCard(
          title: '卡片标题',
          child: Text('卡片内容'),
        ),
      ));
      expect(find.text('卡片标题'), findsOneWidget);
      expect(find.text('卡片内容'), findsOneWidget);
    });

    testWidgets('SectionCard：无标题时不渲染标题占位', (tester) async {
      await tester.pumpWidget(_wrap(
        const SectionCard(child: Text('仅内容')),
      ));
      expect(find.text('仅内容'), findsOneWidget);
    });

    testWidgets('StatCircle：渲染数值/单位/标签（E1 合并后唯一实现）',
        (tester) async {
      // 注：测试字体（FlutterTest）字形为 1em 方块，'28.0' 会在 76px 圆内
      // 折行溢出（真机 MiSans 数字宽约 0.5em 无此现象），故用短值 '28'。
      await tester.pumpWidget(_wrap(
        const StatCircle(value: '28', label: '平均周期', unit: '天'),
      ));
      expect(find.text('28'), findsOneWidget);
      expect(find.text('天'), findsOneWidget);
      expect(find.text('平均周期'), findsOneWidget);
    });

    testWidgets('EmptyState：渲染图标/主文案/副文案', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: Icons.bar_chart,
          message: '暂无统计数据',
          subtitle: '记录经期后即可查看统计',
        ),
      ));
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.text('暂无统计数据'), findsOneWidget);
      expect(find.text('记录经期后即可查看统计'), findsOneWidget);
    });

    testWidgets('LegendItem：渲染图例圆点与标签描述', (tester) async {
      await tester.pumpWidget(_wrap(
        const LegendItem(
          color: AppColors.brandPrimary,
          label: '经期中',
          description: '已记录的经期日期',
        ),
      ));
      expect(find.text('经期中'), findsOneWidget);
      expect(find.text('已记录的经期日期'), findsOneWidget);
    });
  });
}
