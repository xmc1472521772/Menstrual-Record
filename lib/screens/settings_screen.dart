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
                _buildReminderDaysSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildReminderHourSetting(context, settingsProvider),
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
      BuildContext context, SettingsProvider provider) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingSm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: const Icon(
            Icons.notifications,
            color: AppColors.brandPrimary,
            size: 24,
          ),
        ),
        title: Text(
          AppStrings.reminderDays,
          style: AppTheme.titleMedium.copyWith(
            color: context.themeColors.onSurface,
          ),
        ),
        subtitle: Text(
          '提前 ${provider.reminderDays} 天提醒',
          style: AppTheme.bodyMedium.copyWith(
            color: context.themeColors.onSurfaceSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: context.themeColors.onSurfaceTertiary,
        ),
        onTap: () => _showNumberPicker(
          context: context,
          title: AppStrings.reminderDays,
          value: provider.reminderDays,
          min: 1,
          max: 7,
          onChanged: (value) => provider.setReminderDays(value),
        ),
      ),
    );
  }

  Widget _buildReminderHourSetting(
      BuildContext context, SettingsProvider provider) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingLg,
          vertical: AppDimens.spacingSm,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: const Icon(
            Icons.access_time,
            color: AppColors.brandPrimary,
            size: 24,
          ),
        ),
        title: Text(
          AppStrings.reminderTime,
          style: AppTheme.titleMedium.copyWith(
            color: context.themeColors.onSurface,
          ),
        ),
        subtitle: Text(
          '${provider.reminderHour}:00',
          style: AppTheme.bodyMedium.copyWith(
            color: context.themeColors.onSurfaceSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: context.themeColors.onSurfaceTertiary,
        ),
        onTap: () => _showNumberPicker(
          context: context,
          title: AppStrings.reminderTime,
          value: provider.reminderHour,
          min: 0,
          max: 23,
          onChanged: (value) => provider.setReminderHour(value),
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

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '经期数据导出',
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
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
          title: const Text('选择备份'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final file = backups[index];
                final name = file.path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.backup_outlined, size: 20),
                  title: Text(name.replaceAll('auto_backup_', '').replaceAll('.json', '')),
                  onTap: () => Navigator.pop(ctx, file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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

  void _showNumberPicker({
    required BuildContext context,
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    int selectedValue = value;
    final TextEditingController textController =
        TextEditingController(text: value.toString());
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canDecrease = selectedValue > min;
            final canIncrease = selectedValue < max;
            return AlertDialog(
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
                      Icons.tune_rounded,
                      color: AppColors.brandPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingSm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTheme.headingSmall.copyWith(
                        color: context.themeColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── 数值显示 + 加减控制 ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingLg,
                      vertical: AppDimens.spacingXl,
                    ),
                    decoration: BoxDecoration(
                      color: context.themeColors.surfaceTile,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Column(
                      children: [
                        // 加减按钮 + 输入框：三者固定高度，水平居中对齐
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 减少按钮
                            _buildStepButton(
                              context: context,
                              icon: Icons.remove_rounded,
                              enabled: canDecrease,
                              onTap: () {
                                setState(() {
                                  selectedValue--;
                                  textController.text =
                                      selectedValue.toString();
                                  errorText = null;
                                });
                              },
                            ),
                            const SizedBox(width: AppDimens.spacingLg),
                            // 数值输入框（固定高度，不随 errorText 变化）
                            SizedBox(
                              width: 100,
                              height: 48,
                              child: TextField(
                                controller: textController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: AppTheme.statValue.copyWith(
                                  color: AppColors.brandPrimary,
                                  fontSize: 28,
                                ),
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: AppDimens.spacingXs,
                                    vertical: AppDimens.spacingXs,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusMd),
                                    borderSide: BorderSide(
                                      color: AppColors.brandPrimary
                                          .withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimens.radiusMd),
                                    borderSide: const BorderSide(
                                      color: AppColors.brandPrimary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor:
                                      context.themeColors.surfaceCard,
                                ),
                                onChanged: (text) {
                                  final newValue = int.tryParse(text);
                                  if (newValue == null) {
                                    setState(() {
                                      errorText = '请输入有效数字';
                                      selectedValue = value;
                                    });
                                  } else if (newValue < min) {
                                    setState(() {
                                      errorText = '最小值为 $min';
                                      selectedValue = newValue;
                                    });
                                  } else if (newValue > max) {
                                    setState(() {
                                      errorText = '最大值为 $max';
                                      selectedValue = newValue;
                                    });
                                  } else {
                                    setState(() {
                                      errorText = null;
                                      selectedValue = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppDimens.spacingLg),
                            // 增加按钮
                            _buildStepButton(
                              context: context,
                              icon: Icons.add_rounded,
                              enabled: canIncrease,
                              onTap: () {
                                setState(() {
                                  selectedValue++;
                                  textController.text =
                                      selectedValue.toString();
                                  errorText = null;
                                });
                              },
                            ),
                          ],
                        ),
                        // 错误提示（独立行，不影响 Row 内部对齐）
                        const SizedBox(height: AppDimens.spacingXs),
                        SizedBox(
                          height: 18,
                          child: errorText != null
                              ? Text(
                                  errorText!,
                                  style: AppTheme.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: AppColors.error,
                                  ),
                                )
                              : Text(
                                  '有效范围 $min - $max',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: context
                                        .themeColors.onSurfaceTertiary,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                ElevatedButton(
                  onPressed: errorText == null
                      ? () {
                          onChanged(selectedValue);
                          Navigator.pop(ctx);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.white,
                    elevation: AppDimens.elevationNone,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacing2xl,
                      vertical: AppDimens.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                  child: const Text(AppStrings.confirm),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      textController.dispose();
    });
  }

  /// 构建数字选择器的加减按钮
  Widget _buildStepButton({
    required BuildContext context,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.brandPrimary
              : AppColors.brandPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        child: Icon(
          icon,
          color: enabled
              ? AppColors.white
              : AppColors.brandPrimary.withValues(alpha: 0.4),
          size: 22,
        ),
      ),
    );
  }
}
