import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';

void showLeaveCycleSettingsDialog(BuildContext context, WidgetRef ref) {
  final settings = ref.read(settingsProvider);
  String selectedCycle = settings.leaveResetCycle;
  DateTime? manualDate = settings.customLeaveCycleStartDate;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        final currentLabel = NepaliCalendarEngine.getLeaveCycleLabel(
          cycleType: selectedCycle,
          manualStartDate: manualDate,
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.event_repeat, color: Color(0xFF0075db)),
              SizedBox(width: 8),
              Text('Leave Reset & Cycle Settings',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose when employee annual leave balances (Casual, Sick, Annual, etc.) reset, or choose a custom date to reset all balances.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: Color(0xFF0075db)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Cycle: $currentLabel',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Reset Frequency / Cycle Mode:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCycle,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'nepali_fiscal',
                            child: Text(
                                'Nepali Fiscal Year (1 Shrawan) [Default / Standard]'),
                          ),
                          DropdownMenuItem(
                            value: 'nepali_year',
                            child: Text('Nepali Calendar Year (1 Baisakh)'),
                          ),
                          DropdownMenuItem(
                            value: 'calendar_year',
                            child: Text('English Calendar Year (1 January)'),
                          ),
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text('Custom Cycle / Specific Reset Date'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCycle = val;
                              if (val != 'manual') manualDate = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  if (selectedCycle == 'manual') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Custom Cycle Start Date:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                        manualDate != null
                            ? formatNepaliDate(manualDate!, 'dd MMM yyyy (BS)')
                            : 'Select Cycle Start Date',
                      ),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Leave Cycle Start Date',
                          initialStart: manualDate ?? DateTime.now(),
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) {
                          setDialogState(() => manualDate = picked['start']!);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Manual Action:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Reset All Leave Balances to Full Now',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (confirmCtx) => AlertDialog(
                          title:
                              const Text('Confirm Immediate Leave Reset'),
                          content: const Text(
                            'Are you sure you want to reset all employee leave balances to full starting today?\n\n'
                            'All past leave requests will remain safe in history for records, but won\'t count against the new cycle.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(confirmCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  Navigator.pop(confirmCtx, true),
                              child: const Text('Reset Now'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref
                            .read(settingsProvider.notifier)
                            .resetAllLeaveBalancesNow(DateTime.now());
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'All employee leave balances have been reset starting from today!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0075db),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ref
                    .read(settingsProvider.notifier)
                    .setLeaveResetCycle(selectedCycle);
                if (selectedCycle == 'manual' && manualDate != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .resetAllLeaveBalancesNow(manualDate);
                } else if (selectedCycle != 'manual') {
                  await ref
                      .read(settingsProvider.notifier)
                      .clearManualLeaveCycleDate();
                }
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Leave reset cycle updated to: ${NepaliCalendarEngine.getLeaveCycleLabel(cycleType: selectedCycle, manualStartDate: manualDate)}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save Settings'),
            ),
          ],
        );
      },
    ),
  );
}
