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

  /// 确保设置已从 DB 加载完成，返回加载完成的 Future（重复调用安全）。
  ///
  /// [ChangeNotifierProvider] 默认懒创建：若用户冷启动后不经过设置页直接
  /// 进入需要设置值的页面（如多选日历计算延展天数），首次 read 会触发
  /// 创建并开始异步 loadSettings，此刻立即读 getter 只能拿到构造默认值。
  /// 因此任何读取设置值做业务决策的路径都必须先 await 本方法。
  Future<void> ensureLoaded() => _loadFuture ??= loadSettings();

  Future<void> loadSettings() async {
    try {
      _cycleLength = await _dao.getCycleLength();
      _periodLength = await _dao.getPeriodLength();
      _reminderDays = await _dao.getReminderDays();
      _reminderHour = await _dao.getReminderHour();
      _algorithm = await _dao.getPredictionAlgorithm();
      _mergeThreshold = await _dao.getMergeThreshold();
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
}
