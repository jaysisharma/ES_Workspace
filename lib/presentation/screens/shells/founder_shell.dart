import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/founder_navigation_provider.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';
import '../founder/founder_dashboard.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/admin/admin_attendance_dashboard.dart';
import 'package:order_app/presentation/screens/common/finance/revenue_summary_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';

class FounderShell extends ConsumerWidget {
  const FounderShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(founderNavigationProvider);

    final List<Widget> screens = const [
      FounderDashboard(),
      HrManagementScreen(),
      AdminAttendanceDashboard(),
      RevenueSummaryScreen(),
      FinancialLedgerScreen(),
      EventFinancialReportScreen(),
      SynologyCompanyPdfScreen(),
      SettingsScreen(),
    ];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : Colors.white;
    final surfaceDark = isDarkMode ? const Color(0xFF1b262f) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b)
        : const Color(0xFFe2e8f0);
    final unselectedColor = const Color(0xFF64748b);
    final authState = ref.watch(authNotifierProvider);

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Desktop Navigation Sidebar for Founder
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Header Branding
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
                                  fontFamily: 'Manrope',
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Executive Suite',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748b),
                                  fontWeight: FontWeight.w500,
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

                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          0,
                          Icons.grid_view_outlined,
                          Icons.grid_view,
                          'EXECUTIVE OVERVIEW',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          1,
                          Icons.badge_outlined,
                          Icons.badge,
                          'HR & EMPLOYEES',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          2,
                          Icons.co_present_outlined,
                          Icons.co_present,
                          'ATTENDANCE LOGS',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          3,
                          Icons.payments_outlined,
                          Icons.payments,
                          'FINANCIALS',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          4,
                          Icons.account_balance_wallet_outlined,
                          Icons.account_balance_wallet,
                          'FINANCIAL LEDGER',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          5,
                          Icons.analytics_outlined,
                          Icons.analytics,
                          'EVENT REPORTS',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          6,
                          Icons.picture_as_pdf_outlined,
                          Icons.picture_as_pdf,
                          'COMPANY PROFILE',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          ref,
                          selectedIndex,
                          7,
                          Icons.settings_outlined,
                          Icons.settings,
                          'SETTINGS',
                          primaryColor,
                          unselectedColor,
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: borderColor),

                  // User Card Footer
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
                              (authState.user?.email ?? 'F')[0].toUpperCase(),
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
                                  authState.user?.email ?? 'Founder',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Executive / Founder',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748b),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Logout',
                            onPressed: () => ref
                                .read(authNotifierProvider.notifier)
                                .logout(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Screen View
            Expanded(
              child: IndexedStack(
                index: selectedIndex < screens.length ? selectedIndex : 0,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: selectedIndex < screens.length ? selectedIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceDark,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex < 3 ? selectedIndex : 0,
          onTap: (index) {
            ref.read(founderNavigationProvider.notifier).setIndex(index);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: unselectedColor,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.grid_view_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.grid_view, size: 24),
              ),
              label: 'OVERVIEW',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.payments_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.payments, size: 24),
              ),
              label: 'FINANCE',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings, size: 24),
              ),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    WidgetRef ref,
    int currentIndex,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    Color primaryColor,
    Color unselectedColor,
  ) {
    final isSelected = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(founderNavigationProvider.notifier).setIndex(index);
          },
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
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? primaryColor : unselectedColor,
                    letterSpacing: 1.0,
                    fontFamily: 'Manrope',
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
