// 历史记录行标签构建的回归测试。
//
// 背景：历史数据中存在 mood/symptoms 为非 null 空串（或含空白项）的
// 记录，旧逻辑直接判 null 导致 Wrap 渲染出不可见的空行（Text('') 也
// 占一行高，约 +25px），表现为"越靠后的记录行间距越大、行与行错位"。
// buildRecordTags 必须对空白内容完全免疫。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/models/period_record.dart';
import 'package:yimaflutter/screens/record_screen.dart';

PeriodRecord _rec({String? mood, String? symptoms}) =>
    PeriodRecord(startDate: '2026-09-01', mood: mood, symptoms: symptoms);

void main() {
  group('buildRecordTags 空白安全', () {
    test('mood/symptoms 均为 null → 无标签', () {
      expect(buildRecordTags(_rec()), isEmpty);
    });

    test('mood 为空串 → 无标签（不产生隐形空行）', () {
      expect(buildRecordTags(_rec(mood: '')), isEmpty);
    });

    test('mood 为纯空白 → 无标签', () {
      expect(buildRecordTags(_rec(mood: '   ')), isEmpty);
    });

    test('symptoms 为空串/逗号/空白项 → 无标签', () {
      expect(buildRecordTags(_rec(symptoms: '')), isEmpty);
      expect(buildRecordTags(_rec(symptoms: ',')), isEmpty);
      expect(buildRecordTags(_rec(symptoms: ' , , ')), isEmpty);
    });

    test('mood 为空串但 symptoms 有效 → 仅渲染症状标签', () {
      final tags = buildRecordTags(_rec(mood: '', symptoms: '头痛,失眠'));
      // SizedBox + Wrap
      expect(tags.length, 2);
      final wrap = tags[1] as Wrap;
      expect(wrap.children.length, 2);
    });

    test('症状项两侧空白被 trim', () {
      final tags = buildRecordTags(_rec(symptoms: ' 头痛 , 失眠 '));
      final wrap = tags[1] as Wrap;
      expect(wrap.children.length, 2);
      final first = wrap.children.first as Container;
      final text = first.child as Text;
      expect(text.data, '头痛');
    });

    test('有效 mood 正常渲染', () {
      final tags = buildRecordTags(_rec(mood: '😊'));
      expect(tags.length, 2);
      final wrap = tags[1] as Wrap;
      expect(wrap.children.length, 1);
      expect((wrap.children.first as Text).data, '😊');
    });
  });
}
