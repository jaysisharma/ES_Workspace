import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/common/finance/expense_breakdown_screen.dart';
import 'package:order_app/presentation/screens/common/finance/revenue_breakdown_screen.dart';
import 'package:order_app/presentation/widgets/common/receipt_viewer_modal.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsFinancialSummaryWidget extends StatelessWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  final UserRole? userRole;
  final Color primaryColor;
  final Color primaryWellColor;
  final Color successColor;
  final Color warningColor;
  final Color inputBgColor;
  final Color textColor;
  final Color labelColor;
  final String currencyLabel;

  const OrderDetailsFinancialSummaryWidget({
    super.key,
    required this.order,
    required this.items,
    required this.userRole,
    required this.primaryColor,
    required this.primaryWellColor,
    required this.successColor,
    required this.warningColor,
    required this.inputBgColor,
    required this.textColor,
    required this.labelColor,
    required this.currencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isAdminOrFounder = userRole == UserRole.admin || userRole == UserRole.founder || userRole == UserRole.finance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryWellColor,
            primaryWellColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabelWidget(
                'FINANCIAL SUMMARY',
                labelColor: labelColor,
                accentColor: primaryColor,
              ),
              if (isAdminOrFounder)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order.totalAmount > 0
                        ? successColor.withValues(alpha: 0.1)
                        : warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.totalAmount > 0 ? 'FINALIZED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: order.totalAmount > 0
                          ? successColor
                          : warningColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FinanceCardWidget(
                  label: 'Total Revenue',
                  amount: order.totalAmount,
                  color: primaryColor,
                  surfaceColor: inputBgColor,
                  textColor: textColor,
                  labelColor: labelColor,
                  currencyLabel: currencyLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinanceCardWidget(
                  label: 'Expenses',
                  amount: order.totalExpenses,
                  color: warningColor,
                  surfaceColor: inputBgColor,
                  textColor: textColor,
                  labelColor: labelColor,
                  currencyLabel: currencyLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinanceCardWidget(
                  label: 'Net Profit',
                  amount: order.totalAmount - order.totalExpenses,
                  color: successColor,
                  surfaceColor: inputBgColor,
                  textColor: textColor,
                  labelColor: labelColor,
                  currencyLabel: currencyLabel,
                ),
              ),
            ],
          ),
          if (order.advanceReceived > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.advanceReferenceNo.isNotEmpty
                            ? 'Advance (${order.advanceReferenceNo})'
                            : 'Advance Received',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      if (order.advanceReceiptName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            ReceiptViewerModal.show(
                              context,
                              title: order.advanceReceiptName,
                              url: order.advanceReceiptUrl,
                              path: order.advanceReceiptPath,
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 10,
                                  color: Colors.teal,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'RECEIPT',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '$currencyLabel ${order.advanceReceived.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isAdminOrFounder) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(
                          page: RevenueBreakdownScreen(
                            order: order,
                            items: items,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                    ),
                    label: const Text('View Revenue Breakdown'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      backgroundColor: primaryColor.withValues(
                        alpha: 0.05,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      minimumSize: const Size(
                        double.infinity,
                        0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(
                          page: ExpenseBreakdownScreen(
                            order: order,
                            items: items,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                    ),
                    label: const Text('View Expense Breakdown'),
                    style: TextButton.styleFrom(
                      foregroundColor: warningColor,
                      backgroundColor: warningColor.withValues(
                        alpha: 0.05,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      minimumSize: const Size(
                        double.infinity,
                        0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
