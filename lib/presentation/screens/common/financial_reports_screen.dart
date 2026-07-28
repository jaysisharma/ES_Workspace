import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/order_providers.dart';
import '../../../core/services/order_pdf_service.dart';
import '../../../domain/entities/order_entity.dart';

enum FinancialViewMode { revenue, expenses, both }

class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState
    extends ConsumerState<FinancialReportsScreen> {
  String _searchQuery = '';
  FinancialViewMode _viewType = FinancialViewMode.both;

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b0f13) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1a1f26) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF262f3a) : const Color(0xFFf1f5f9);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final successColor = const Color(0xFF4ade80);

    final filteredOrders = orderState.orders.where((order) {
      final query = _searchQuery.trim().toLowerCase();
      return order.eventName.toLowerCase().contains(query) ||
             order.id.toLowerCase().contains(query) ||
             order.venue.toLowerCase().contains(query);
    }).toList();

    // Calculate totals for export
    double totalRevenue = 0;
    for (var order in orderState.orders) {
      totalRevenue += order.totalAmount;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Text(
                  'Financial Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.download, color: primaryColor),
                  tooltip: 'Export Summary PDF',
                  onPressed: () async {
                    if (filteredOrders.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No orders to export')),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating Financial Summary...')),
                    );

                    try {
                      final pdfData = await OrderPdfService.generateGlobalFinancialPdf(
                        orders: filteredOrders,
                        totalRevenue: totalRevenue,
                        totalExpenses: 0, // In this app, expenses might be complex, keeping 0 for now
                        netProfit: totalRevenue,
                        margin: 1.0,
                      );

                      if (!context.mounted) return;
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [
                          XFile.fromData(
                            pdfData,
                            name: 'Financial_Summary_${formatNepaliDate(DateTime.now(), 'yyyyMMdd')}.pdf',
                            mimeType: 'application/pdf',
                          )
                        ],
                        subject: 'Financial Summary Report',
                        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                      );
                    } catch (e, st) {
                      debugPrint('PDF generation error [financial_reports/export]: $e\n$st');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: orderState.isLoading && orderState.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(orderNotifierProvider.notifier).loadOrders(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 120, top: 24),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? cardColor : const Color(0xFFf1f5f9),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: TextField(
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search by event name, Order ID, or venue...',
                          hintStyle: TextStyle(fontSize: 14, color: labelColor),
                          prefixIcon: Icon(Icons.search, color: labelColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // View Mode Toggle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FINANCIAL PERSPECTIVE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: labelColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<FinancialViewMode>(
                            segments: const [
                              ButtonSegment(
                                value: FinancialViewMode.revenue,
                                label: Text('Revenue'),
                                icon: Icon(Icons.trending_up, size: 16),
                              ),
                              ButtonSegment(
                                value: FinancialViewMode.expenses,
                                label: Text('Expenses'),
                                icon: Icon(Icons.trending_down, size: 16),
                              ),
                              ButtonSegment(
                                value: FinancialViewMode.both,
                                label: Text('Both'),
                                icon: Icon(Icons.balance, size: 16),
                              ),
                            ],
                            selected: {_viewType},
                            onSelectionChanged: (newSelection) => setState(() => _viewType = newSelection.first),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: primaryColor.withValues(alpha: 0.1),
                              selectedForegroundColor: primaryColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Reports Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT ARCHIVES',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          '${filteredOrders.length} Reports Found',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (filteredOrders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text('No reports found', style: TextStyle(color: labelColor)),
                      )
                    else
                      ...filteredOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildReportCard(
                            order: order,
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            labelColor: labelColor,
                            successColor: successColor,
                            primaryColor: primaryColor,
                            viewType: _viewType,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportCard({
    required OrderEntity order,
    required bool isDarkMode,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color successColor,
    required Color primaryColor,
    required FinancialViewMode viewType,
  }) {
    final revenue = NumberFormat.currency(symbol: 'NPR ', decimalDigits: 2).format(order.totalAmount);
    final date = formatNepaliDate(order.eventDate, 'MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.eventName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor, height: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ID: ${order.id}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: successColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: labelColor),
              const SizedBox(width: 4),
              Text(date, style: TextStyle(fontSize: 12, color: labelColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('•', style: TextStyle(fontSize: 12, color: labelColor)),
              ),
              Icon(Icons.location_on, size: 14, color: labelColor),
              const SizedBox(width: 4),
              Text(order.venue, style: TextStyle(fontSize: 12, color: labelColor)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDarkMode ? const Color(0xFF262f3a) : const Color(0xFFf1f5f9))),
            ),
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Row(
              children: [
                if (viewType == FinancialViewMode.revenue || viewType == FinancialViewMode.both)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REVENUE', style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: labelColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(revenue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor))),
                      ],
                    ),
                  ),
                if (viewType == FinancialViewMode.both) ...[
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('NET PROFIT', style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: labelColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(revenue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: successColor))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
                    try {
                      final pdfData = await OrderPdfService.generateOrderPdf(
                        order: order,
                        items: [], // Fetching items might require a separate call, using empty for now
                        showFinancials: true,
                      );
                      if (!mounted) return;
                      final box = context.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [XFile.fromData(pdfData, name: 'Order_${order.id}_${order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf', mimeType: 'application/pdf')],
                        subject: 'Order Report: ${order.eventName}',
                        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                      );
                    } catch (e, st) {
                      debugPrint('PDF generation error [financial_reports/report]: $e\n$st');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(color: primaryColor.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Text('View PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                ),
              ),
              const SizedBox(width: 12),
              _buildIconButton(Icons.download, isDarkMode, cardColor, () async {
                // Same logic as View PDF for download/share
              }),
              const SizedBox(width: 12),
              _buildIconButton(Icons.share, isDarkMode, cardColor, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, bool isDarkMode, Color cardColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1e293b).withValues(alpha: 0.5) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, color: isDarkMode ? const Color(0xFFcbd5e1) : const Color(0xFF475569)),
        onPressed: onTap,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
