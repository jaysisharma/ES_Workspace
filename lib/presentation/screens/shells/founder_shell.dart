import 'package:flutter/material.dart';
import 'package:order_app/presentation/screens/founder/founder_dashboard.dart';
import 'package:order_app/presentation/widgets/common/app_drawer.dart';

class FounderShell extends StatelessWidget {
  const FounderShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(),
      body: FounderDashboard(),
    );
  }
}
