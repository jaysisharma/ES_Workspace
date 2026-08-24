import 'package:flutter/material.dart';
import 'package:order_app/presentation/screens/admin/new_dashboard.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NewDashboard(),
    );
  }
}

