import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/presentation/widgets/hr_management/manage_geofence_dialog.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_cycle_settings_dialog.dart';
import 'package:order_app/presentation/widgets/create_order/manage_categories_dialog.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/inventory/inventory_management_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class CompanyPoliciesScreen extends ConsumerWidget {
  const CompanyPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                  'Company & Operational Policies',
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
            Text(
              'Manage organizational rules, geofencing, leave resets, and system catalog.',
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildPolicyTile(
                    title: 'Office Geofence Zone',
                    subtitle: 'Configure GPS Coordinates & attendance verification radius',
                    icon: Icons.share_location_rounded,
                    iconColor: const Color(0xFF0075db),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => const ManageGeofenceDialog(),
                    ),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: false,
                  ),
                  _buildPolicyTile(
                    title: 'Leave Reset & Cycle Settings',
                    subtitle: 'Configure annual leave entitlements & automatic reset schedules',
                    icon: Icons.event_repeat_rounded,
                    iconColor: const Color(0xFF10b981),
                    onTap: () => showLeaveCycleSettingsDialog(context, ref),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: false,
                  ),
                  _buildPolicyTile(
                    title: 'Order & Event Categories',
                    subtitle: 'Add, edit & organize catering and event service categories',
                    icon: Icons.category_rounded,
                    iconColor: const Color(0xFFf59e0b),
                    onTap: () => ManageCategoriesDialog.show(context),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: false,
                  ),
                  _buildPolicyTile(
                    title: 'Company Profile & Synology Documents',
                    subtitle: 'Upload, manage & share company assets and files via Synology NAS',
                    icon: Icons.cloud_upload_outlined,
                    iconColor: const Color(0xFFe11d48),
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                    ),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: false,
                  ),
                  _buildPolicyTile(
                    title: 'Inventory & Equipment Master',
                    subtitle: 'Track available equipment stock, rental rates & rental items',
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFFa855f7),
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const InventoryManagementScreen()),
                    ),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: true,
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

  Widget _buildPolicyTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required Color textColor,
    required Color labelColor,
    required Color dividerColor,
    required bool isLast,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: labelColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: labelColor.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
