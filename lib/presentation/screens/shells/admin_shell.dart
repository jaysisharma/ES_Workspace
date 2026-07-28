import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import '../admin/admin_dashboard.dart';
import '../admin/hr_management_screen.dart';
import '../admin/admin_attendance_dashboard.dart';
import '../staff/staff_attendance_screen.dart';
import '../common/vendor_screen.dart';
import '../common/client_screen.dart';
import '../common/purchase_order_list_screen.dart';
import '../common/revenue_summary_screen.dart';
import '../common/financial_ledger_screen.dart';
import '../common/event_financial_report_screen.dart';
import '../common/calendar_screen.dart';
import '../common/settings_screen.dart';
import '../../widgets/app_drawer.dart';
import '../common/create_order_screen.dart';
import '../../providers/auth_provider.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminDashboard(),
    HrManagementScreen(),
    AdminAttendanceDashboard(),
    StaffAttendanceScreen(),
    VendorScreen(),
    ClientScreen(),
    PurchaseOrderListScreen(),
    RevenueSummaryScreen(),
    FinancialLedgerScreen(),
    EventFinancialReportScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b)
        : const Color(0xFFe2e8f0);
    final unselectedColor = const Color(0xFF64748b);
    final authState = ref.watch(authNotifierProvider);

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    final fab = _selectedIndex == 0
        ? FloatingActionButton.extended(
            heroTag: 'admin_orders_fab',
            onPressed: () => Navigator.push(
              context,
              SlidePageRoute(page: const CreateOrderScreen()),
            ),
            backgroundColor: primaryColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Create Order',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
        : null;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Full Desktop Sidebar Navigation
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // App Title Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/event_solution_logo.jpeg',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ES Workspace',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Roboto',
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Enterprise Suite',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748b),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),

                  // Full Desktop Navigation Menu List
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildDesktopNavItem(
                          index: 0,
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 1,
                          icon: Icons.badge_outlined,
                          activeIcon: Icons.badge,
                          label: 'HR & Employees',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 2,
                          icon: Icons.access_time_outlined,
                          activeIcon: Icons.access_time_filled,
                          label: 'Attendance Logs',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 3,
                          icon: Icons.how_to_reg_outlined,
                          activeIcon: Icons.how_to_reg,
                          label: 'My Attendance',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 4,
                          icon: Icons.business_center_outlined,
                          activeIcon: Icons.business_center,
                          label: 'Vendors',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 5,
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: 'Clients',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 6,
                          icon: Icons.description_outlined,
                          activeIcon: Icons.description,
                          label: 'Purchase Orders',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 7,
                          icon: Icons.analytics_outlined,
                          activeIcon: Icons.analytics,
                          label: 'Financials',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 8,
                          icon: Icons.account_balance_wallet_outlined,
                          activeIcon: Icons.account_balance_wallet,
                          label: 'Financial Ledger',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 9,
                          icon: Icons.summarize_outlined,
                          activeIcon: Icons.summarize,
                          label: 'Event Reports',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 10,
                          icon: Icons.calendar_month_outlined,
                          activeIcon: Icons.calendar_month,
                          label: 'Calendar',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                        _buildDesktopNavItem(
                          index: 11,
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: 'Settings',
                          primaryColor: primaryColor,
                          unselectedColor: unselectedColor,
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: borderColor),

                  // Desktop User Profile & Logout Bottom Card
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryColor,
                            child: Text(
                              (authState.user?.email ?? 'A')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authState.user?.email ?? 'Admin',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748b),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                            tooltip: 'Logout',
                            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Desktop Content Workspace
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ],
        ),
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ColorFilter.mode(
              bgColor.withValues(alpha: 0.1),
              BlendMode.srcOver,
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
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
                    child: Icon(Icons.list_alt_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      Icons.list_alt,
                      size: 26,
                      color: primaryColor,
                      shadows: const [
                        Shadow(blurRadius: 10, color: Colors.blue),
                      ],
                    ),
                  ),
                  label: 'ORDERS',
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.badge_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      Icons.badge,
                      size: 26,
                      color: primaryColor,
                    ),
                  ),
                  label: 'HR SYSTEM',
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.business_center_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      Icons.business_center,
                      size: 26,
                      color: primaryColor,
                    ),
                  ),
                  label: 'VENDORS',
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.payments_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.payments, size: 26, color: primaryColor),
                  ),
                  label: 'REVENUE',
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.calendar_month_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      Icons.calendar_month,
                      size: 26,
                      color: primaryColor,
                    ),
                  ),
                  label: 'CALENDAR',
                ),
                BottomNavigationBarItem(
                  icon: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.settings_outlined, size: 26),
                  ),
                  activeIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.settings, size: 26, color: primaryColor),
                  ),
                  label: 'SETTINGS',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: fab,
    );
  }

  Widget _buildDesktopNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color primaryColor,
    required Color unselectedColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? primaryColor : unselectedColor,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected ? primaryColor : unselectedColor,
                    letterSpacing: 0.2,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
