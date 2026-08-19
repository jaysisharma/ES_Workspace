import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/finance/revenue_summary_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_invoices_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/orders/purchase_order_list_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/admin/admin_attendance_dashboard.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/common/inventory/inventory_management_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = ref.watch(authNotifierProvider).user?.role;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                if (role == UserRole.admin ||
                    role == UserRole.founder ||
                    role == UserRole.finance) ...[
                  _DrawerTile(
                    icon: Icons.badge_outlined,
                    label: 'HR & Employees',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const HrManagementScreen());
                    },
                  ),
                ],
                if (role == UserRole.admin || role == UserRole.founder) ...[
                  _DrawerTile(
                    icon: Icons.access_time_outlined,
                    label: 'Attendance & Logs',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const AdminAttendanceDashboard());
                    },
                  ),
                ],
                if (role == UserRole.admin) ...[
                  _DrawerTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventory Management',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const InventoryManagementScreen());
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.description_outlined,
                    label: 'Purchase Orders',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const PurchaseOrderListScreen());
                    },
                  ),
                ],
                if (role == UserRole.admin ||
                    role == UserRole.founder ||
                    role == UserRole.finance) ...[
                  _DrawerTile(
                    icon: Icons.business_outlined,
                    label: 'Vendors',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const VendorScreen());
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.people_outline,
                    label: 'Clients',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const ClientScreen());
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.description_outlined,
                    label: 'Event Reports',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const EventFinancialReportScreen());
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Invoices & Billing',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const EventInvoicesScreen());
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Financial Ledger',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const FinancialLedgerScreen());
                    },
                  ),
                ],
                if (role == UserRole.founder) ...[
                  _DrawerTile(
                    icon: Icons.analytics_outlined,
                    label: 'Revenue Summary',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const RevenueSummaryScreen());
                    },
                  ),
                ],
                _DrawerTile(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Company Profile & Share',
                  onTap: () {
                    Navigator.pop(context);
                    context.pushPage(const SynologyCompanyPdfScreen());
                  },
                ),
                if (role == UserRole.admin ||
                    role == UserRole.founder ||
                    role == UserRole.staff)
                  _DrawerTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Calendar',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushPage(const CalendarScreen());
                    },
                  ),
                const Divider(indent: 16, endIndent: 16),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.pushPage(const SettingsScreen());
                  },
                ),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 64, bottom: 24, left: 24, right: 24),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ES Workspace',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'Management System',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Text(
            'v1.2.0',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Handle Logout
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      visualDensity: VisualDensity.compact,
    );
  }
}
