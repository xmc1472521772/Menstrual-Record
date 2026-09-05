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
                _buildSectionTitle(context, '周期参数'),
                _buildPredictionHint(context),
                const SizedBox(height: AppDimens.spacingMd),
                _buildCycleLengthSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildPeriodLengthSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacing2xl),
                _buildSectionTitle(context, '提醒设置'),
                _buildReminderDaysSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacingSm),
                _buildReminderHourSetting(context, settingsProvider),
                const SizedBox(height: AppDimens.spacing2xl),
                _buildSectionTitle(context, AppStrings.dataManagement),
                _buildExportButton(context, periodProvider),
                const SizedBox(height: AppDimens.spacingMd),
                _buildImportButton(context, periodProvider),
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
          '提醒时间',
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
          title: '提醒时间',
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

  Future<void> _exportData(
      BuildContext context, PeriodProvider provider) async {
    try {
      final jsonData = await provider.exportData();
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'period_data_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '经期数据导出',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据导出成功（明文 JSON，请妥善保管）'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
              '选择导入模式：',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(success ? AppStrings.importSuccess : AppStrings.importError),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
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
            return AlertDialog(
              title: Text(
                title,
                style: AppTheme.headingSmall.copyWith(
                  color: context.themeColors.onSurface,
                ),
              ),
              content: SizedBox(
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: textController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppTheme.statValue.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingSm,
                            vertical: AppDimens.spacingSm,
                          ),
                          errorText: errorText,
                          errorStyle: AppTheme.bodySmall.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        onChanged: (text) {
                          final newValue = int.tryParse(text);
                          if (newValue == null) {
                            setState(() {
                              errorText = '请输入数字';
                              selectedValue = value;
                            });
                          } else if (newValue < min) {
                            setState(() {
                              errorText = '不能小于 $min 天';
                              selectedValue = newValue;
                            });
                          } else if (newValue > max) {
                            setState(() {
                              errorText = '不能大于 $max 天';
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
                    const SizedBox(height: AppDimens.spacingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: selectedValue > min
                              ? () {
                                  setState(() {
                                    selectedValue--;
                                    textController.text =
                                        selectedValue.toString();
                                    errorText = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 40,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: AppDimens.spacing2xl),
                        IconButton(
                          onPressed: selectedValue < max
                              ? () {
                                  setState(() {
                                    selectedValue++;
                                    textController.text =
                                        selectedValue.toString();
                                    errorText = null;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 40,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                    Text(
                      '范围: $min - $max',
                      style: AppTheme.bodySmall.copyWith(
                        color: context.themeColors.onSurfaceTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: errorText == null
                      ? () {
                          onChanged(selectedValue);
                          Navigator.pop(ctx);
                        }
                      : null,
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
}
