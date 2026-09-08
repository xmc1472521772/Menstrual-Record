import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 自动备份服务（P1-5 从 PeriodProvider 迁出 + P0-2 备份去抖）。
///
/// - [schedule]：注册一次备份请求。内置 [debounceWindow]（30 秒）trailing
///   去抖——窗口内多次数据变更合并为一次全量导出，连续操作时消除
///   「一次写操作 = 一次全量序列化 + 一次文件 IO」的 IO 峰值；持续操作
///   会不断重置计时器，直到数据静默满 30 秒才真正落盘。
/// - [cancel]：取消未触发的备份。数据源 Provider dispose 时必须调用，
///   避免定时器在对象树销毁后访问已失效的数据源。
///
/// 备份文件写入应用文档目录 `backups/`，只保留最近 [maxBackups] 份
/// （5 份），超出时删除最旧的。所有异常静默处理——备份失败不应影响
/// 正常使用。
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// 备份去抖窗口（trailing）。
  static const Duration debounceWindow = Duration(seconds: 30);

  /// 保留的备份文件数量上限。
  static const int maxBackups = 5;

  Timer? _timer;

  /// 是否有待触发的备份（供测试与诊断）。
  @visibleForTesting
  bool get hasPendingBackup => _timer != null && _timer!.isActive;

  /// 安排一次自动备份（trailing 去抖）。
  ///
  /// [export] 回调在去抖窗口到期时执行，返回完整的导出 JSON 字符串。
  /// 以回调形式注入数据源，本服务不依赖任何 Provider，可独立单测。
  void schedule(Future<String> Function() export) {
    _timer?.cancel();
    _timer = Timer(debounceWindow, () => _runBackup(export));
  }

  /// 取消未触发的备份。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 执行备份：导出 → 写文件 → 清理旧备份。
  /// 全程异常静默（与迁移前的 _autoBackup 策略一致）。
  Future<void> _runBackup(Future<String> Function() export) async {
    _timer = null;
    try {
      final jsonData = await export();

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }
      final now = DateTime.now();
      final fileName =
          'auto_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonData);

      // 清理旧备份：只保留最近 [maxBackups] 份
      final backups = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (backups.length > maxBackups) {
        for (final old in backups.skip(maxBackups)) {
          try {
            old.deleteSync();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }
}
