import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/finance_navigation_provider.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';
import 'package:order_app/presentation/screens/common/finance/finance_dashboard.dart';
import 'package:order_app/presentation/screens/common/finance/event_invoices_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/orders/purchase_order_list_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';

class FinanceShell extends ConsumerWidget {
  const FinanceShell({super.key});

  static const List<int> _bottomNavScreenIndices = [0, 1, 2, 3, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(financeNavigationProvider);

    final List<Widget> screens = const [
      FinanceDashboard(), // 0 - Dedicated Finance Dashboard
      EventInvoicesScreen(), // 1 - Invoices & Billing
      FinancialLedgerScreen(), // 2 - Financial Ledger
      EventFinancialReportScreen(), // 3 - Event Reports
      HrManagementScreen(), // 4 - HR & Payroll
      VendorScreen(), // 5 - Vendors
      ClientScreen(), // 6 - Clients
      PurchaseOrderListScreen(), // 7 - Purchase Orders
      CalendarScreen(), // 8 - Calendar & Schedule
      SynologyCompanyPdfScreen(), // 9 - Company Profile
      SettingsScreen(), // 10 - Settings
    ];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b)
        : const Color(0xFFe2e8f0);
    final unselectedColor = const Color(0xFF64748b);

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      // Desktop / Mac: Full-screen view without sidebar, driven by intuitive module cards & header search
      return Scaffold(
        backgroundColor: bgColor,
        body: IndexedStack(
          index: selectedIndex < screens.length ? selectedIndex : 0,
          children: screens,
        ),
      );
    }

    // Mobile / Tablet: Responsive view with Drawer & bottom navigation
    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: selectedIndex < screens.length ? selectedIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavScreenIndices.contains(selectedIndex)
              ? _bottomNavScreenIndices.indexOf(selectedIndex)
              : 0,
          onTap: (index) {
            ref
                .read(financeNavigationProvider.notifier)
                .setIndex(_bottomNavScreenIndices[index]);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: unselectedColor,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: unselectedColor,
            letterSpacing: 1.2,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.dashboard_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.dashboard, size: 24, color: primaryColor),
              ),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.receipt_long_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.receipt_long, size: 24, color: primaryColor),
              ),
              label: 'INVOICES',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.account_balance_wallet_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              label: 'LEDGER',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.analytics_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.analytics, size: 24, color: primaryColor),
              ),
              label: 'REPORTS',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.badge_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.badge, size: 24, color: primaryColor),
              ),
              label: 'HR',
            ),
          ],
        ),
      ),
    );
  }
}
