import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/screens/staff/staff_dashboard.dart';
import 'package:order_app/presentation/screens/staff/tasks_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_profile_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/widgets/common/role_based_router.dart';

class StaffShell extends ConsumerStatefulWidget {
  const StaffShell({super.key});

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    StaffDashboard(),
    TasksScreen(),
    CalendarScreen(),
    StaffAttendanceScreen(),
    StaffProfileScreen(),
    SynologyCompanyPdfScreen(),
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

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Left Desktop Navigation Sidebar for Staff
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // App Header
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
                                'Staff Portal',
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

                  // Sidebar Options
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNavItem(
                          0,
                          Icons.assignment_outlined,
                          Icons.assignment,
                          'WORK OVERVIEW',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          1,
                          Icons.checklist_outlined,
                          Icons.checklist,
                          'MY TASKS',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          2,
                          Icons.calendar_month_outlined,
                          Icons.calendar_month,
                          'CALENDAR',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          3,
                          Icons.access_time_outlined,
                          Icons.access_time_filled,
                          'MY ATTENDANCE',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          4,
                          Icons.person_outline,
                          Icons.person,
                          'MY PROFILE',
                          primaryColor,
                          unselectedColor,
                        ),
                        _buildNavItem(
                          5,
                          Icons.picture_as_pdf_outlined,
                          Icons.picture_as_pdf,
                          'COMPANY PROFILE',
                          primaryColor,
                          unselectedColor,
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: borderColor),

                  // Footer User Card & Logout
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
                              (authState.user?.email ?? 'S')[0].toUpperCase(),
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
                                  authState.user?.email ?? 'Staff',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Team Staff',
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
                            onPressed: () async {
                              await ref
                                  .read(authNotifierProvider.notifier)
                                  .logout();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const RoleBasedRouter()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1a2632) : const Color(0xFFf5f7f8),
          border: Border(top: BorderSide(color: borderColor)),
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
                child: Icon(Icons.assignment_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.assignment, size: 24),
              ),
              label: 'EVENTS',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.checklist_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.checklist, size: 24),
              ),
              label: 'TASKS',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.calendar_month_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.calendar_month, size: 24),
              ),
              label: 'CALENDAR',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.access_time_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.access_time_filled, size: 24),
              ),
              label: 'ATTENDANCE',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person_outline, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.person, size: 24),
              ),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    Color primaryColor,
    Color unselectedColor,
  ) {
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
