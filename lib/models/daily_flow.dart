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
}
