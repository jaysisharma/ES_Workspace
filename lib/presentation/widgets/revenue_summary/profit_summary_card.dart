import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfitSummaryCard extends StatelessWidget {
  final double netProfit;
  final double margin;
  final double currentTotalRevenue;
  final double totalExpenses;
  final String currencyLabel;

  const ProfitSummaryCard({
    super.key,
    required this.netProfit,
    required this.margin,
    required this.currentTotalRevenue,
    required this.totalExpenses,
    required this.currencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final emeraldColor = colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.account_balance_wallet,
              size: 120,
              color: colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insights,
                              size: 14,
                              color: colorScheme.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PROJECT NET PROFIT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.8,
                                ),
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$currencyLabel ${NumberFormat('#,##0.00').format(netProfit)}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: netProfit >= 0
                                  ? emeraldColor
                                  : colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: emeraldColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: emeraldColor, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${margin.toStringAsFixed(1)}% Margin',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: emeraldColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: colorScheme.primary.withValues(alpha: 0.1)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL REVENUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$currencyLabel ${NumberFormat('#,##0.00').format(currentTotalRevenue)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL EXPENSES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$currencyLabel ${NumberFormat('#,##0.00').format(totalExpenses)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
