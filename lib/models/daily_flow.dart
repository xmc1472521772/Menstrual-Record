/// 每日经量记录。
///
/// 存储经期中每一天的经量等级（0=无, 1=少, 2=中, 3=多）。
/// 与 [PeriodRecord] 分离，因为同一段经期内每天的经量可能不同。
class DailyFlow {
  final int? id;
  final String date; // yyyy-MM-dd
  final int flowLevel; // 0=无, 1=少, 2=中, 3=多

  DailyFlow({
    this.id,
    required this.date,
    required this.flowLevel,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'date': date,
      'flow_level': flowLevel,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory DailyFlow.fromMap(Map<String, dynamic> map) {
    return DailyFlow(
      id: map['id'] as int?,
      date: map['date'] as String,
      flowLevel: map['flow_level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'flowLevel': flowLevel,
    };
  }

  factory DailyFlow.fromJson(Map<String, dynamic> json) {
    return DailyFlow(
      date: json['date'] as String,
      // 范围校验：导入的越界脏数据钳制到合法区间 0-3
      flowLevel: ((json['flowLevel'] as num?)?.toInt() ?? 0).clamp(0, 3).toInt(),
    );
  }
}
