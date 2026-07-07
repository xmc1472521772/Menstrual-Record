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
  String _algorithm = 'simple';

  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  int get reminderDays => _reminderDays;
  int get reminderHour => _reminderHour;
  String get algorithm => _algorithm;

  Future<void> loadSettings() async {
    try {
      _cycleLength = await _dao.getCycleLength();
      _periodLength = await _dao.getPeriodLength();
      _reminderDays = await _dao.getReminderDays();
      _reminderHour = await _dao.getReminderHour();
      _algorithm = await _dao.getPredictionAlgorithm();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setCycleLength(int value) async {
    _cycleLength = value;
    await _dao.setValue('avg_cycle_length', value.toString());
    notifyListeners();
  }

  Future<void> setPeriodLength(int value) async {
    _periodLength = value;
    await _dao.setValue('avg_period_length', value.toString());
    notifyListeners();
  }

  Future<void> setReminderDays(int value) async {
    _reminderDays = value;
    await _dao.setValue('reminder_days', value.toString());
    notifyListeners();
  }

  Future<void> setReminderHour(int value) async {
    _reminderHour = value;
    await _dao.setValue('reminder_hour', value.toString());
    notifyListeners();
  }

  Future<void> setAlgorithm(String value) async {
    _algorithm = value;
    await _dao.setValue('prediction_algorithm', value);
    notifyListeners();
  }
}
