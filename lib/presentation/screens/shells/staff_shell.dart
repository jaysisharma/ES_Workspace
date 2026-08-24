import 'package:flutter/material.dart';
import 'package:order_app/presentation/screens/staff/staff_dashboard.dart';

class StaffShell extends StatelessWidget {
  const StaffShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: StaffDashboard(),
    );
  }
}

