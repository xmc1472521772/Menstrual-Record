import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: Consumer2<PeriodProvider, SettingsProvider>(
        builder: (context, periodProvider, settingsProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacingLg,
              AppDimens.spacingLg,
              AppDimens.spacingLg,
              100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle(context, AppStrings.cycleParams),
                _buildPredictionHint(context),
                const SizedBox(height: AppDimens.spacingMd),
                _buildCycleLengthSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildPeriodLengthSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacing2xl),
                _buildSectionTitle(context, AppStrings.reminderSettings),
                _buildReminderDaysSetting(
                    context, settingsProvider, periodProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildReminderHourSetting(
                    context, settingsProvider, periodProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildReminderToggleSetting(
                  context,
                  icon: Icons.edit_note_rounded,
                  title: AppStrings.reminderPeriodDaily,
                  subtitle: AppStrings.reminderPeriodDailyDesc,
                  value: settingsProvider.reminderPeriodDaily,
                  onChanged: (v) async {
                    await settingsProvider.setReminderPeriodDaily(v);
                    periodProvider.syncNotifications();
                  },
                ),
                const SizedBox(height: AppDimens.spacingSm),
                _buildReminderToggleSetting(
                  context,
                  icon: Icons.favorite_rounded,
                  title: AppStrings.reminderOvulation,
                  subtitle: AppStrings.reminderOvulationDesc,
                  value: settingsProvider.reminderOvulation,
                  onChanged: (v) async {
                    await settingsProvider.setReminderOvulation(v);
                    periodProvider.syncNotifications();
                  },
                ),
                const SizedBox(height: AppDimens.spacing2xl),
                _buildSectionTitle(context, AppStrings.dataManagement),
                _buildExportButton(context, periodProvider),
                const SizedBox(height: AppDimens.spacingMd),
                _buildImportButton(context, periodProvider),
                const SizedBox(height: AppDimens.spacingMd),
                _buildRestoreBackupButton(context, periodProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spacingMd),
      child: Text(
        title,
        style: AppTheme.headingSmall.copyWith(
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  Widget _buildPredictionHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.brandSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.brandPrimary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppDimens.spacingSm),
          Expanded(
            child: Text(
              '当有足够的历史记录时，系统会根据实际记录计算平均值；当记录不足时，会使用以下默认值进行预测。',
              style: AppTheme.bodySmall.copyWith(
                color: context.themeColors.onSurfaceSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleLengthSetting(
      BuildContext context, SettingsProvider provider) {
    return _buildSliderSetting(
      context: context,
      title: AppStrings.cycleLength,
      icon: Icons.calendar_month,
      value: provider.cycleLength,
      min: 20,
      max: 45,
      onChanged: (v) => provider.setCycleLength(v.round()),
    );
  }

  Widget _buildPeriodLengthSetting(
      BuildContext context, SettingsProvider provider) {
    return _buildSliderSetting(
      context: context,
      title: AppStrings.periodDuration,
      icon: Icons.water_drop,
      value: provider.periodLength,
      min: 2,
      max: 10,
      onChanged: (v) => provider.setPeriodLength(v.round()),
    );
  }

  Widget _buildSliderSetting({
    required BuildContext context,
    required String title,
    required IconData icon,
    required int value,
    required int min,
    required int max,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spacingLg,
          AppDimens.spacingLg,
          AppDimens.spacingLg,
          AppDimens.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Icon(icon, color: AppColors.brandPrimary, size: 16),
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      color: context.themeColors.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$value 天',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacingSm),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value 天',
              activeColor: AppColors.brandPrimary,
              inactiveColor: AppColors.tile,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderDaysSetting(
      BuildContext context, SettingsProvider provider, PeriodProvider periodProvider) {
    return _buildSliderSetting(
      context: context,
      title: AppStrings.reminderDays,
      icon: Icons.notifications_rounded,
      value: provider.reminderDays,
      min: 1,
      max: 7,
      onChanged: (v) async {
        await provider.setReminderDays(v.round());
        // 提前天数变化影响已排提醒的触发时刻，立即同步
        periodProvider.syncNotifications();
      },
    );
  }

  Widget _buildReminderHourSetting(BuildContext context,
      SettingsProvider provider, PeriodProvider periodProvider) {
    final hour = provider.reminderHour;
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:00';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingSm,
        ),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: const Icon(
            Icons.access_time_rounded,
            color: AppColors.brandPrimary,
            size: 16,
          ),
        ),
        title: Text(
          AppStrings.reminderTime,
          style: AppTheme.titleMedium.copyWith(
            color: context.themeColors.onSurface,
          ),
        ),
        subtitle: Text(
          timeStr,
          style: AppTheme.bodyMedium.copyWith(
            color: context.themeColors.onSurfaceSecondary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Text(
            timeStr,
            style: AppTheme.titleMedium.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => _pickReminderTime(context, provider, periodProvider),
      ),
    );
  }

  Future<void> _pickReminderTime(BuildContext context,
      SettingsProvider provider, PeriodProvider periodProvider) async {
    final initialTime = TimeOfDay(hour: provider.reminderHour, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        final themeColors = context.themeColors;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.brandPrimary,
                  onPrimary: AppColors.white,
                  surface: themeColors.surfaceCard,
                  onSurface: themeColors.onSurface,
                  surfaceContainerHighest: themeColors.surfaceTile,
                ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: themeColors.surfaceCard,
              dayPeriodColor: AppColors.brandPrimary.withValues(alpha: 0.15),
              dayPeriodTextColor: AppColors.brandPrimary,
              dayPeriodBorderSide: BorderSide(
                color: AppColors.brandPrimary.withValues(alpha: 0.3),
              ),
              dialBackgroundColor: themeColors.surfaceTile,
              dialHandColor: AppColors.brandPrimary,
              dialTextColor: themeColors.onSurface,
              hourMinuteColor: themeColors.surfaceTile,
              hourMinuteTextColor: themeColors.onSurface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radius2xl),
              ),
              helpTextStyle: AppTheme.bodySmall.copyWith(
                color: themeColors.onSurfaceSecondary,
              ),
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                    themeColors.onSurfaceSecondary),
                textStyle: WidgetStateProperty.all(AppTheme.labelLarge),
              ),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppColors.brandPrimary),
                textStyle: WidgetStateProperty.all(
                    AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    await provider.setReminderHour(picked.hour);
    // 提醒时间变化影响全部提醒的触发时刻，立即同步
    periodProvider.syncNotifications();
  }

  /// 提醒开关设置项（经期记录提醒 / 排卵期提示）。
  ///
  /// 切换后由调用方通过 [onChanged] 持久化并触发通知同步，
  /// 开关状态由 [value]（SettingsProvider 内存值）驱动，随重建刷新。
  Widget _buildReminderToggleSetting(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMd,
          vertical: AppDimens.spacingXs,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 16),
            ),
            const SizedBox(width: AppDimens.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      color: context.themeColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: context.themeColors.onSurfaceSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.brandPrimary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, PeriodProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _exportData(context, provider),
        icon: const Icon(Icons.upload, size: 20),
        label: const Text(AppStrings.exportData),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingLg,
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, PeriodProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _importData(context, provider),
        icon: const Icon(Icons.download, size: 20),
        label: const Text(AppStrings.importData),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingLg,
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreBackupButton(
      BuildContext context, PeriodProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _restoreBackup(context, provider),
        icon: const Icon(Icons.history, size: 20),
        label: const Text('恢复自动备份'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacingLg,
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(
      BuildContext context, PeriodProvider provider) async {
    try {
      final jsonData = await provider.exportData();
      if (!context.mounted) return;
      final directory = await getApplicationDocumentsDirectory();
      if (!context.mounted) return;
      final now = DateTime.now();
      final fileName =
          'period_data_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonData);
      if (!context.mounted) return;

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: '经期数据导出'),
      );

      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(AppStrings.exportSuccessHint),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importData(
      BuildContext context, PeriodProvider provider) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      final pickedPath = picked?.path;
      if (pickedPath == null) return;

      final file = File(pickedPath);
      final jsonString = await file.readAsString();

      if (context.mounted) {
        final mode = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.importMode),
            content: Text(
              AppStrings.selectImportMode,
              style: AppTheme.bodyMedium.copyWith(
                color: context.themeColors.onSurfaceSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'append'),
                child: const Text(AppStrings.appendImport),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'overwrite'),
                child: const Text(AppStrings.overwriteImport),
              ),
            ],
          ),
        );

        if (mode == null) return;

        final success = await provider.importData(
          jsonString,
          overwrite: mode == 'overwrite',
        );

        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content:
                  Text(success ? AppStrings.importSuccess : AppStrings.importError),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(
      BuildContext context, PeriodProvider provider) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!backupDir.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('暂无自动备份')),
          );
        }
        return;
      }

      final backups = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (backups.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('暂无自动备份')),
          );
        }
        return;
      }

      // 显示备份列表供用户选择
      if (!context.mounted) return;
      final selected = await showDialog<File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.brandPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppDimens.spacingSm),
              Expanded(
                child: Text(
                  '选择备份',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.themeColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.themeColors.divider),
              itemBuilder: (context, index) {
                final file = backups[index];
                final isLatest = index == 0;
                // 解析文件名中的日期时间
                // 格式: auto_backup_20260907_143052.json
                final rawName =
                    file.path.split(RegExp(r'[/\\]')).last;
                final dateStr = rawName
                    .replaceAll('auto_backup_', '')
                    .replaceAll('.json', '');
                // 提取 yyyyMMdd 和 HHmmss 两部分
                final parts = dateStr.split('_');
                String displayDate = rawName;
                String displayTime = '';
                if (parts.length == 2 &&
                    parts[0].length == 8 &&
                    parts[1].length == 6) {
                  final year = parts[0].substring(0, 4);
                  final month = parts[0].substring(4, 6);
                  final day = parts[0].substring(6, 8);
                  final hour = parts[1].substring(0, 2);
                  final minute = parts[1].substring(2, 4);
                  displayDate = '$year年$month月$day日';
                  displayTime = '$hour:$minute';
                }
                // 文件大小
                final fileSize = file.lengthSync();
                final sizeStr = fileSize > 1024
                    ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
                    : '$fileSize B';

                return InkWell(
                  onTap: () => Navigator.pop(ctx, file),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                      vertical: AppDimens.spacingMd,
                    ),
                    decoration: BoxDecoration(
                      color: isLatest
                          ? AppColors.brandSoft.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSm),
                      border: isLatest
                          ? Border.all(
                              color: AppColors.brandPrimary
                                  .withValues(alpha: 0.2),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLatest
                              ? Icons.backup_table_rounded
                              : Icons.backup_outlined,
                          size: 20,
                          color: isLatest
                              ? AppColors.brandPrimary
                              : context.themeColors.onSurfaceTertiary,
                        ),
                        const SizedBox(width: AppDimens.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayDate,
                                    style: AppTheme.titleMedium.copyWith(
                                      color: isLatest
                                          ? AppColors.brandPrimary
                                          : context.themeColors.onSurface,
                                      fontWeight: isLatest
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.spacingSm),
                                  Text(
                                    displayTime,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: isLatest
                                          ? AppColors.brandPrimary
                                              .withValues(alpha: 0.8)
                                          : context.themeColors.onSurfaceSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppDimens.spacingSm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandPrimary,
                                        borderRadius:
                                            BorderRadius.circular(
                                                AppDimens.radiusFull),
                                      ),
                                      child: const Text(
                                        '最新',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sizeStr,
                                style: AppTheme.bodySmall.copyWith(
                                  color: context.themeColors.onSurfaceTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor:
                    context.themeColors.onSurfaceSecondary,
                textStyle: AppTheme.labelLarge,
              ),
              child: const Text(AppStrings.cancel),
            ),
          ],
        ),
      );

      if (selected == null) return;

      final jsonString = await selected.readAsString();
      final success = await provider.importData(jsonString, overwrite: true);

      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(success ? '备份已恢复' : '恢复失败'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }
}
