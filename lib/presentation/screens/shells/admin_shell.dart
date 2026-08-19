import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/screens/admin/new_dashboard.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/admin/admin_attendance_dashboard.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/orders/purchase_order_list_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;
  static const List<int> _bottomNavScreenIndices = [0, 1, 7, 9, 11];

  final List<Widget> _screens = const [
    NewDashboard(), // 0 - New sorted dashboard with direct action module cards
    HrManagementScreen(), // 1
    AdminAttendanceDashboard(), // 2
    StaffAttendanceScreen(), // 3
    VendorScreen(), // 4
    ClientScreen(), // 5
    PurchaseOrderListScreen(), // 6
    FinancialLedgerScreen(), // 7
    EventFinancialReportScreen(), // 8
    CalendarScreen(), // 9
    SynologyCompanyPdfScreen(), // 10
    SettingsScreen(), // 11
  ];

  @override
  Widget build(BuildContext context) {
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
          index: _selectedIndex < _screens.length ? _selectedIndex : 0,
          children: _screens,
        ),
      );
    }

    // Mobile / Tablet: Responsive view with Drawer & bottom navigation
    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex < _screens.length ? _selectedIndex : 0,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomNavScreenIndices.contains(_selectedIndex)
              ? _bottomNavScreenIndices.indexOf(_selectedIndex)
              : 0,
          onTap: (index) => setState(
            () => _selectedIndex = _bottomNavScreenIndices[index],
          ),
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
                child: Icon(Icons.badge_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.badge, size: 24, color: primaryColor),
              ),
              label: 'HR SYSTEM',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.account_balance_wallet_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.account_balance_wallet, size: 24, color: primaryColor),
              ),
              label: 'LEDGER',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.calendar_month_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Icons.calendar_month,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              label: 'CALENDAR',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings, size: 24, color: primaryColor),
              ),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}
