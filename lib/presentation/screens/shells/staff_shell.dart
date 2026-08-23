import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/screens/staff/staff_dashboard.dart';
import 'package:order_app/presentation/screens/staff/tasks_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_profile_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';

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

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      // Desktop / Mac: Full-screen view without sidebar, driven by intuitive module cards & header actions
      return Scaffold(
        backgroundColor: bgColor,
        body: IndexedStack(
          index: _selectedIndex < _screens.length ? _selectedIndex : 0,
          children: _screens,
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
}
