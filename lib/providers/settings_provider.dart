import 'dart:async';
import 'package:flutter/material.dart';
import '../database/settings_dao.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsDao _dao;

  /// Allows injecting a [SettingsDao] for testing; defaults to the singleton.
  SettingsProvider({SettingsDao? settingsDao}) : _dao = settingsDao ?? SettingsDao();

  int _cycleLength = 28;
  int _periodLength = 5;
  int _reminderDays = 2;
  int _reminderHour = 9;
  String _algorithm = 'adaptive';
  int _mergeThreshold = 2;
  String _reportModel = 'glm-4-flash';
  String _chatModel = 'glm-4-flash';

  /// 经期每日记录提醒开关（默认开）。
  bool _reminderPeriodDaily = true;

  /// 排卵期提示开关（默认开）。
  bool _reminderOvulation = true;

  /// 首页状态卡紧凑模式（C1）：true 时折叠双均值条，让日历网格
  /// 在首屏更完整地露出。点击状态卡均值区切换，偏好持久化。
  bool _heroCompact = false;

  /// 首次 [ensureLoaded] 时创建的加载任务；并发调用共享同一份 Future。
  Future<void>? _loadFuture;

  /// 滑块防抖定时器：拖动过程中只更新内存值（UI 即时响应），
  /// 松手后延迟写入数据库，避免每像素变化都触发一次 DB 写入。
  Timer? _cycleLengthDebounce;
  Timer? _periodLengthDebounce;

  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  int get reminderDays => _reminderDays;
  int get reminderHour => _reminderHour;
  String get algorithm => _algorithm;
  int get mergeThreshold => _mergeThreshold;
  String get reportModel => _reportModel;
  String get chatModel => _chatModel;
  bool get reminderPeriodDaily => _reminderPeriodDaily;
  bool get reminderOvulation => _reminderOvulation;
  bool get heroCompact => _heroCompact;

  /// 确保设置已从 DB 加载完成，返回加载完成的 Future（重复调用安全）。
  ///
  /// [ChangeNotifierProvider] 默认懒创建：若用户冷启动后不经过设置页直接
  /// 进入需要设置值的页面（如多选日历计算延展天数），首次 read 会触发
  /// 创建并开始异步 loadSettings，此刻立即读 getter 只能拿到构造默认值。
  /// 因此任何读取设置值做业务决策的路径都必须先 await 本方法。
  Future<void> ensureLoaded() => _loadFuture ??= loadSettings();

  Future<void> loadSettings() async {
    try {
      // 同源单查询：冷启动路径原先串行 8 次 getValue()（每次一次 DB 往返），
      // 现改为一次 getAll() 取回全部设置项后按 key 解析，DB 往返 8 → 1。
      // 各字段的解析与默认值回退逻辑与 [SettingsDao] 中对应 getter 保持
      // 一致（包括 'weighted'→'adaptive' 兼容映射与 ai_model 旧 key 回退），
      // 未来新增设置项时两处需同步维护——取舍：设置项总数个位数且变动
      // 极少，单查询带来的启动收益远大于双处维护的成本。
      final all = await _dao.getAll();

      _cycleLength = int.tryParse(all['avg_cycle_length'] ?? '28') ?? 28;
      _periodLength = int.tryParse(all['avg_period_length'] ?? '5') ?? 5;
      _reminderDays = int.tryParse(all['reminder_days'] ?? '2') ?? 2;
      _reminderHour = int.tryParse(all['reminder_hour'] ?? '9') ?? 9;
      final algorithmValue = all['prediction_algorithm'];
      // 兼容旧版：'weighted' 统一映射为 'adaptive'
      // （原 SettingsDao.getPredictionAlgorithm 内的映射逻辑）
      _algorithm = algorithmValue == 'weighted'
          ? 'adaptive'
          : (algorithmValue ?? 'adaptive');
      _mergeThreshold = int.tryParse(all['merge_threshold'] ?? '2') ?? 2;
      // 兼容旧版单一 ai_model 设置
      _reportModel = all['ai_report_model'] ?? all['ai_model'] ?? 'glm-4-flash';
      _chatModel = all['ai_chat_model'] ?? all['ai_model'] ?? 'glm-4-flash';
      // 提醒开关：'1' 开，其余（'0'/缺失历史前的旧数据）按默认开处理
      _reminderPeriodDaily = (all['reminder_period_daily'] ?? '1') == '1';
      _reminderOvulation = (all['reminder_ovulation'] ?? '1') == '1';
      // 首页状态卡紧凑模式：默认展开（'0'/缺失）
      _heroCompact = (all['home_hero_compact'] ?? '0') == '1';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<bool> setCycleLength(int value) async {
    _cycleLength = value;
    notifyListeners();
    _cycleLengthDebounce?.cancel();
    _cycleLengthDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _dao.setValue('avg_cycle_length', value.toString());
      } catch (e) {
        debugPrint('Error setting cycle length: $e');
      }
    });
    return true;
  }

  Future<bool> setPeriodLength(int value) async {
    _periodLength = value;
    notifyListeners();
    _periodLengthDebounce?.cancel();
    _periodLengthDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _dao.setValue('avg_period_length', value.toString());
      } catch (e) {
        debugPrint('Error setting period length: $e');
      }
    });
    return true;
  }

  Future<bool> setReminderDays(int value) async {
    try {
      await _dao.setValue('reminder_days', value.toString());
      _reminderDays = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting reminder days: $e');
      return false;
    }
  }

  Future<bool> setReminderHour(int value) async {
    try {
      await _dao.setValue('reminder_hour', value.toString());
      _reminderHour = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting reminder hour: $e');
      return false;
    }
  }

  Future<bool> setAlgorithm(String value) async {
    try {
      await _dao.setValue('prediction_algorithm', value);
      _algorithm = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting algorithm: $e');
      return false;
    }
  }

  Future<bool> setMergeThreshold(int value) async {
    try {
      await _dao.setValue('merge_threshold', value.toString());
      _mergeThreshold = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting merge threshold: $e');
      return false;
    }
  }

  Future<bool> setReportModel(String value) async {
    try {
      await _dao.setValue('ai_report_model', value);
      _reportModel = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting report model: $e');
      return false;
    }
  }

  Future<bool> setChatModel(String value) async {
    try {
      await _dao.setValue('ai_chat_model', value);
      _chatModel = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting chat model: $e');
      return false;
    }
  }

  /// 设置经期每日记录提醒开关（开关切换无高频写入，不走防抖）。
  Future<bool> setReminderPeriodDaily(bool value) async {
    try {
      await _dao.setValue('reminder_period_daily', value ? '1' : '0');
      _reminderPeriodDaily = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting reminder period daily: $e');
      return false;
    }
  }

  /// 设置排卵期提示开关。
  Future<bool> setReminderOvulation(bool value) async {
    try {
      await _dao.setValue('reminder_ovulation', value ? '1' : '0');
      _reminderOvulation = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting reminder ovulation: $e');
      return false;
    }
  }

  /// 设置首页状态卡紧凑模式（点击均值区切换，C1）。
  Future<bool> setHeroCompact(bool value) async {
    try {
      await _dao.setValue('home_hero_compact', value ? '1' : '0');
      _heroCompact = value;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting hero compact: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // 取消未触发的防抖写入，避免 dispose 后 Timer 回调仍访问 _dao
    _cycleLengthDebounce?.cancel();
    _periodLengthDebounce?.cancel();
    super.dispose();
  }
}
