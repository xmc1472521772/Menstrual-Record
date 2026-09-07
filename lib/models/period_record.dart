class PeriodRecord {
  final int? id;
  final String startDate;
  final String? endDate;
  final int? cycleLength;
  final int? periodLength;
  final int? flowLevel;
  final String? mood;
  final String? notes;
  final String? symptoms;
  final int createdAt;

  /// 经量等级：1=偏少, 2=正常, 3=偏多, null=未设置
  static const int flowLight = 1;
  static const int flowNormal = 2;
  static const int flowHeavy = 3;

  PeriodRecord({
    this.id,
    required this.startDate,
    this.endDate,
    this.cycleLength,
    this.periodLength,
    this.flowLevel,
    this.mood,
    this.notes,
    this.symptoms,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
      'cycle_length': cycleLength,
      'period_length': periodLength,
      'flow_level': flowLevel,
      'mood': mood,
      'notes': notes,
      'symptoms': symptoms,
      'created_at': createdAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory PeriodRecord.fromMap(Map<String, dynamic> map) {
    return PeriodRecord(
      id: map['id'] as int?,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      cycleLength: map['cycle_length'] as int?,
      periodLength: map['period_length'] as int?,
      flowLevel: map['flow_level'] as int?,
      mood: map['mood'] as String?,
      notes: map['notes'] as String?,
      symptoms: map['symptoms'] as String?,
      createdAt: map['created_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate,
      'endDate': endDate,
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'flowLevel': flowLevel,
      'mood': mood,
      'notes': notes,
      'symptoms': symptoms,
      'createdAt': createdAt,
    };
  }

  factory PeriodRecord.fromJson(Map<String, dynamic> json) {
    final startDateStr = json['startDate'];
    if (startDateStr == null || startDateStr is! String || startDateStr.isEmpty) {
      throw const FormatException('缺少必填字段 startDate');
    }
    return PeriodRecord(
      startDate: startDateStr,
      endDate: json['endDate'] as String?,
      cycleLength: json['cycleLength'] as int?,
      periodLength: json['periodLength'] as int?,
      flowLevel: json['flowLevel'] as int?,
      mood: (json['mood'] as String?)?.isNotEmpty == true
          ? json['mood'] as String
          : null,
      notes: (json['notes'] as String?)?.isNotEmpty == true
          ? json['notes'] as String
          : null,
      symptoms: (json['symptoms'] as String?)?.isNotEmpty == true
          ? json['symptoms'] as String
          : null,
      createdAt: json['createdAt'] as int?,
    );
  }

  /// Creates a copy of this record with the given fields replaced.
  ///
  /// To set a nullable field to null, use the corresponding `clear*` parameter
  /// (e.g. [clearEndDate]).
  PeriodRecord copyWith({
    int? id,
    String? startDate,
    String? endDate,
    int? cycleLength,
    int? periodLength,
    int? flowLevel,
    String? mood,
    String? notes,
    String? symptoms,
    int? createdAt,
    bool clearEndDate = false,
    bool clearMood = false,
    bool clearNotes = false,
    bool clearSymptoms = false,
    bool clearCycleLength = false,
    bool clearPeriodLength = false,
    bool clearFlowLevel = false,
  }) {
    return PeriodRecord(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      cycleLength:
          clearCycleLength ? null : (cycleLength ?? this.cycleLength),
      periodLength:
          clearPeriodLength ? null : (periodLength ?? this.periodLength),
      flowLevel: clearFlowLevel ? null : (flowLevel ?? this.flowLevel),
      mood: clearMood ? null : (mood ?? this.mood),
      notes: clearNotes ? null : (notes ?? this.notes),
      symptoms: clearSymptoms ? null : (symptoms ?? this.symptoms),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  DateTime get startDateTime => DateTime.parse(startDate);
  DateTime? get endDateTime => endDate != null ? DateTime.parse(endDate!) : null;

  bool get isOngoing => endDate == null;

  int get periodDays {
    if (endDate == null) {
      return DateTime.now().difference(startDateTime).inDays + 1;
    }
    return endDateTime!.difference(startDateTime).inDays + 1;
  }

  /// 计算在给定时间点 [at] 的经期天数。
  ///
  /// 对 ongoing 记录使用 [at] 代替 `DateTime.now()`，
  /// 避免同一帧内多次访问时跨天边界返回不同值。
  int periodDaysAt(DateTime at) {
    if (endDate == null) {
      return at.difference(startDateTime).inDays + 1;
    }
    return endDateTime!.difference(startDateTime).inDays + 1;
  }
}
