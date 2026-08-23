import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/screens/common/finance/financial_reports_screen.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class ExportStorageSettingsScreen extends ConsumerWidget {
  const ExportStorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final dividerColor = isDarkMode
        ? const Color(0xFF1e2d3d).withValues(alpha: 0.6)
        : const Color(0xFFe2e8f0);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textColor),
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Exports, Data & Storage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Directory Path Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284c7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          color: Color(0xFF0284c7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Destination Export Folder',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: settings.exportDestinationDirectory != null
                                        ? const Color(0xFF10b981).withValues(alpha: 0.12)
                                        : const Color(0xFF64748b).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    settings.exportDestinationDirectory != null ? 'CUSTOM' : 'DEFAULT',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: settings.exportDestinationDirectory != null
                                          ? const Color(0xFF10b981)
                                          : const Color(0xFF64748b),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              settings.exportDestinationDirectory != null
                                  ? settings.exportDestinationDirectory!
                                  : 'Default System Downloads Directory',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: settings.exportDestinationDirectory != null
                                    ? primaryColor
                                    : labelColor,
                                fontWeight: settings.exportDestinationDirectory != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final selectedDir = await FilePicker.platform.getDirectoryPath(
                            dialogTitle: 'Select Destination Folder for Exports',
                          );
                          if (selectedDir != null && selectedDir.isNotEmpty) {
                            await ref
                                .read(settingsProvider.notifier)
                                .setExportDestinationDirectory(selectedDir);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Export directory set to: $selectedDir'),
                                  backgroundColor: const Color(0xFF10b981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                        label: const Text('Choose Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      if (settings.exportDestinationDirectory != null) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ExportDirectoryService.openDirectory(
                              settings.exportDestinationDirectory!,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Open in Finder/Explorer', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(settingsProvider.notifier).setExportDestinationDirectory(null);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reset export directory to system default.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Reset', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Arrange in Subfolders',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Organizes exports into Finance/ (Invoices, Ledgers, Reports), Orders/, Attendance/',
                              style: TextStyle(color: labelColor, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Switch.adaptive(
                        value: settings.autoArrangeExportFolders,
                        activeTrackColor: primaryColor,
                        onChanged: (val) {
                          ref.read(settingsProvider.notifier).toggleAutoArrangeExportFolders(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Data Actions
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284c7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.table_chart_rounded, color: Color(0xFF0284c7), size: 20),
                    ),
                    title: Text(
                      'Export All Orders (Excel)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      'Download entire order records in .xlsx format',
                      style: TextStyle(fontSize: 11.5, color: labelColor),
                    ),
                    trailing: const Icon(Icons.download_rounded, size: 20),
                    onTap: () => _exportAllOrdersExcel(context, ref),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10b981), size: 20),
                    ),
                    title: Text(
                      'Financial PDF Statements',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      'Open profit/loss, ledger and invoice summary generator',
                      style: TextStyle(fontSize: 11.5, color: labelColor),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const FinancialReportsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _exportAllOrdersExcel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export Orders to Excel'),
        content: const Text('Generate and export all order statements into an Excel (.xlsx) file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0075db),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final orders = ref.read(orderNotifierProvider).orders;
              final headers = [
                'Order ID',
                'Event Name',
                'Venue',
                'Contact Person',
                'Contact Number',
                'Event Start',
                'Event End',
                'Setup Start',
                'Setup End',
                'Status',
                'Total Amount (NPR)',
                'Advance Received (NPR)',
                'Due Amount (NPR)',
                'Description',
              ];

              final rows = orders
                  .map(
                    (o) => [
                      o.id,
                      o.eventName,
                      o.venue,
                      o.contactPerson,
                      o.contactNumber,
                      formatNepaliDate(o.eventDate, 'yyyy-MM-dd'),
                      o.eventEndDate != null ? formatNepaliDate(o.eventEndDate!, 'yyyy-MM-dd') : '',
                      formatNepaliDate(o.setupDate, 'yyyy-MM-dd'),
                      o.setupEndDate != null ? formatNepaliDate(o.setupEndDate!, 'yyyy-MM-dd') : '',
                      o.status.name,
                      o.totalAmount,
                      o.advanceReceived,
                      (o.totalAmount - o.advanceReceived).clamp(0.0, double.infinity),
                      o.description,
                    ],
                  )
                  .toList();

              await ExcelExportHelper.exportAndShareExcel(
                context: context,
                headers: headers,
                rows: rows,
                filename: 'All_Orders_Export_${formatNepaliDate(DateTime.now(), "yyyyMMdd")}.xlsx',
                sheetName: 'All Orders',
                title: 'All Orders Statement Summary',
              );
            },
            child: const Text('Export Now'),
          ),
        ],
      ),
    );
  }
}
