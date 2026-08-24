import 'package:flutter/material.dart';
import 'package:order_app/presentation/screens/common/finance/finance_dashboard.dart';

class FinanceShell extends StatelessWidget {
  const FinanceShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FinanceDashboard(),
    );
  }
}

