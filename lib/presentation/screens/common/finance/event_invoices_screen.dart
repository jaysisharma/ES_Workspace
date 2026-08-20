import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/finance_excel_export_service.dart';
import 'package:order_app/core/services/invoice_sequence_service.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/number_to_words_converter.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/finance_navigation_provider.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:order_app/presentation/widgets/finance/payment_receipt_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class EventInvoicesScreen extends ConsumerStatefulWidget {
  const EventInvoicesScreen({super.key});

  @override
  ConsumerState<EventInvoicesScreen> createState() =>
      _EventInvoicesScreenState();
}

class _EventInvoicesScreenState extends ConsumerState<EventInvoicesScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _getClientDisplayName(OrderEntity order) {
    if (order.client.trim().isNotEmpty) {
      return order.client.trim();
    }
    if (order.contactPerson.trim().isNotEmpty) {
      return order.contactPerson.trim();
    }
    return order.eventName;
  }

  void _openInvoiceCustomizerDialog(OrderEntity order,
      {required bool isPreviewOnly}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => InvoiceCustomizerModal(
        order: order,
        isPreviewDefault: isPreviewOnly,
      ),
    );
  }

  void _openPaymentDialog(OrderEntity order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PaymentReceiptDialog(order: order),
    );
  }

  void _openEventSelectorDialog(List<OrderEntity> orders) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _EventSelectorModal(
        orders: orders,
        onSelect: (order) {
          Navigator.pop(dialogCtx);
          _openInvoiceCustomizerDialog(order, isPreviewOnly: false);
        },
      ),
    );
  }

  void _sendWhatsAppReminder(OrderEntity order) async {
    final clientPhone =
        order.contactNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final due = (order.totalAmount - order.advanceReceived)
        .clamp(0.0, double.infinity);
    final dueFormatted = CurrencyFormatter.formatWithLabel(due, 'NPR');
    final totalFormatted =
        CurrencyFormatter.formatWithLabel(order.totalAmount, 'NPR');
    final clientName = _getClientDisplayName(order);

    final message =
        'Dear $clientName,\n\nThis is a gentle payment reminder from Event Solution Pvt Ltd regarding the event "${order.eventName}".\n\n'
        '• Total Amount: $totalFormatted\n'
        '• Balance Due: $dueFormatted\n\n'
        'Kindly settle the outstanding balance at your earliest convenience.\n'
        'Thank you!\nEvent Solution Pvt Ltd - Accounts Dept';

    if (clientPhone.isNotEmpty) {
      final cleanNumber = clientPhone.startsWith('+')
          ? clientPhone.substring(1)
          : (clientPhone.startsWith('977')
              ? clientPhone
              : '977$clientPhone');
      final encodedText = Uri.encodeComponent(message);
      final url = Uri.parse('https://wa.me/$cleanNumber?text=$encodedText');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client contact: ${order.contactNumber}'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor =
        isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final cardBg = isDarkMode ? const Color(0xFF16202a) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF334155).withValues(alpha: 0.5)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final subtextColor = const Color(0xFF64748b);

    final ordersStream = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        title: Text(
          'Invoices & Billing',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // 1-Click Excel Export Button
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, size: 20),
            tooltip: 'Export Registry to Excel (.xlsx)',
            color: Colors.teal,
            onPressed: () {
              final orders = ordersStream.value ?? [];
              if (orders.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No invoice records to export.')),
                );
                return;
              }
              FinanceExcelExportService.exportInvoicesRegistry(
                context: context,
                orders: orders,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ordersStream.when(
        data: (orders) {
          // Totals
          double totalInvoiced = 0.0;
          double totalAdvance = 0.0;
          double totalDue = 0.0;

          for (final o in orders) {
            totalInvoiced += o.totalAmount;
            totalAdvance += o.advanceReceived;
            final due = (o.totalAmount - o.advanceReceived)
                .clamp(0.0, double.infinity);
            totalDue += due;
          }

          // Filter groups
          final unpaidOrders = orders
              .where((o) => (o.totalAmount - o.advanceReceived) > 0.01 && o.totalAmount > 0)
              .toList()
            ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

          final paidOrders = orders
              .where((o) => (o.totalAmount - o.advanceReceived) <= 0.01 && o.totalAmount > 0)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final recentActivityOrders = List<OrderEntity>.from(orders)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final isSearching = _searchQuery.trim().isNotEmpty;
          final searchResults = isSearching
              ? orders.where((o) {
                  final q = _searchQuery.toLowerCase().trim();
                  final cleanNoPrefix = q
                      .replaceAll('#', '')
                      .replaceAll('order-', '')
                      .replaceAll('ord-', '')
                      .replaceAll('order', '')
                      .replaceAll('id:', '')
                      .trim();
                  final orderIdLower = o.id.toLowerCase();
                  final isIdMatch = orderIdLower == q ||
                      (cleanNoPrefix.isNotEmpty &&
                          orderIdLower.contains(cleanNoPrefix)) ||
                      orderIdLower.contains(q);

                  return isIdMatch ||
                      o.eventName.toLowerCase().contains(q) ||
                      o.client.toLowerCase().contains(q) ||
                      o.contactPerson.toLowerCase().contains(q);
                }).toList()
              : <OrderEntity>[];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ordersStreamProvider);
            },
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    children: [
                      // Top Quick Action Bar: Generate Proforma Invoice & Quick Search
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                              label: const Text(
                                'Generate Invoice',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () =>
                                  _openEventSelectorDialog(orders),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      size: 18, color: subtextColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      style: TextStyle(
                                          fontSize: 13, color: textColor),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Search by Order ID, client, event...',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: subtextColor,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      onChanged: (val) => setState(
                                          () => _searchQuery = val.trim()),
                                    ),
                                  ),
                                  if (isSearching)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // If searching, display search results directly
                      if (isSearching) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Search Results (${searchResults.length} found)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (searchResults.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Center(
                              child: Text(
                                'No events or invoices match "$_searchQuery"',
                                style: TextStyle(color: subtextColor),
                              ),
                            ),
                          )
                        else
                          ...searchResults.map((order) => _buildInvoiceItemCard(
                                order: order,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              )),
                        const SizedBox(height: 90),
                      ] else ...[
                        // High-Level Financial Metric Strip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryMetric(
                                label: 'TOTAL INVOICED',
                                amount: totalInvoiced,
                                color: primaryColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
                              Container(
                                  height: 30, width: 1, color: borderColor),
                              _buildSummaryMetric(
                                label: 'TOTAL COLLECTED',
                                amount: totalAdvance,
                                color: Colors.green,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
                              Container(
                                  height: 30, width: 1, color: borderColor),
                              _buildSummaryMetric(
                                label: 'PENDING RECEIVABLES',
                                amount: totalDue,
                                color: Colors.orange,
                                textColor: textColor,
                                subtextColor: subtextColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Tab Navigation Header
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF141f28)
                                : const Color(0xFFf1f5f9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: subtextColor,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Manrope',
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Manrope',
                            ),
                            tabs: [
                              Tab(text: 'Pending (${unpaidOrders.length})'),
                              const Tab(text: 'Recent Activity'),
                              Tab(text: 'Paid (${paidOrders.length})'),
                              Tab(text: 'All (${orders.length})'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Tab View Content (Sized container for tabs)
                        SizedBox(
                          height: 520,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // 1. Pending Receivables Tab
                              _buildPendingTab(
                                unpaidOrders: unpaidOrders,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),

                              // 2. Recent Activity Tab (Highlights activity done)
                              _buildRecentActivityTab(
                                orders: recentActivityOrders,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),

                              // 3. Paid Invoices Tab
                              _buildPaidTab(
                                paidOrders: paidOrders,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),

                              // 4. All Invoices Tab
                              _buildAllTab(
                                allOrders: orders,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading invoices: $err'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: BottomRightBackButton(
        label: 'Back to Dashboard',
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            ref.read(financeNavigationProvider.notifier).setIndex(0);
          }
        },
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required double amount,
    required Color color,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: subtextColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          CurrencyFormatter.formatWithLabel(amount, 'NPR'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // 1. Pending Receivables Tab
  Widget _buildPendingTab({
    required List<OrderEntity> unpaidOrders,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    if (unpaidOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 48, color: Colors.green),
            const SizedBox(height: 10),
            Text(
              'No pending receivables!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All client invoices are fully settled.',
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: unpaidOrders.length,
      itemBuilder: (context, index) {
        final order = unpaidOrders[index];
        final due = (order.totalAmount - order.advanceReceived)
            .clamp(0.0, double.infinity);
        return _buildReceivableActionCard(
          order: order,
          dueAmount: due,
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
          primaryColor: primaryColor,
        );
      },
    );
  }

  // 2. Recent Activity Tab (Shows activity done, payments received, PI generated)
  Widget _buildRecentActivityTab({
    required List<OrderEntity> orders,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Text('No recent activity recorded.',
            style: TextStyle(color: subtextColor)),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final due = (order.totalAmount - order.advanceReceived)
            .clamp(0.0, double.infinity);
        final isPaid = due <= 0.01 && order.totalAmount > 0;
        final hasAdvance = order.advanceReceived > 0;

        String activityText;
        IconData activityIcon;
        Color activityColor;

        if (isPaid) {
          activityText =
              'Full Payment Settled (${CurrencyFormatter.formatWithLabel(order.totalAmount, 'NPR')})';
          activityIcon = Icons.check_circle;
          activityColor = Colors.green;
        } else if (hasAdvance) {
          final modeStr = order.advanceReferenceNo.isNotEmpty
              ? ' • ${order.advanceReferenceNo}'
              : '';
          activityText =
              'Partial Payment Received: ${CurrencyFormatter.formatWithLabel(order.advanceReceived, 'NPR')}$modeStr';
          activityIcon = Icons.payments_outlined;
          activityColor = Colors.teal;
        } else {
          activityText = 'Proforma Invoice Active • Awaiting Payment';
          activityIcon = Icons.hourglass_top_rounded;
          activityColor = Colors.orange;
        }

        final clientName = _getClientDisplayName(order);
        final shortId = order.id.length > 6
            ? order.id.substring(0, 6).toUpperCase()
            : order.id.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activityColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(activityIcon, color: activityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$shortId',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            activityText,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: activityColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$clientName • ${order.eventName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Updated: ${formatNepaliDate(order.updatedAt, 'MMM dd, yyyy')}',
                      style: TextStyle(fontSize: 11, color: subtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    tooltip: 'Preview PI',
                    onPressed: () => _openInvoiceCustomizerDialog(
                      order,
                      isPreviewOnly: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        size: 18, color: Color(0xFF0075db)),
                    tooltip: 'Send PI',
                    onPressed: () => _openInvoiceCustomizerDialog(
                      order,
                      isPreviewOnly: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Paid Invoices Tab
  Widget _buildPaidTab({
    required List<OrderEntity> paidOrders,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    if (paidOrders.isEmpty) {
      return Center(
        child: Text('No fully paid invoices recorded yet.',
            style: TextStyle(color: subtextColor)),
      );
    }

    return ListView.builder(
      itemCount: paidOrders.length,
      itemBuilder: (context, index) {
        final order = paidOrders[index];
        final clientName = _getClientDisplayName(order);
        final shortId = order.id.length > 6
            ? order.id.substring(0, 6).toUpperCase()
            : order.id.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$shortId',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PAID IN FULL',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$clientName • ${order.eventName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Total: ${CurrencyFormatter.formatWithLabel(order.totalAmount, 'NPR')} • Settled: ${formatNepaliDate(order.updatedAt, 'yyyy-MM-dd')}',
                      style: TextStyle(fontSize: 11, color: subtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('View PI', style: TextStyle(fontSize: 11)),
                onPressed: () => _openInvoiceCustomizerDialog(
                  order,
                  isPreviewOnly: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. All Invoices Tab
  Widget _buildAllTab({
    required List<OrderEntity> allOrders,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return ListView.builder(
      itemCount: allOrders.length,
      itemBuilder: (context, index) {
        return _buildInvoiceItemCard(
          order: allOrders[index],
          cardBg: cardBg,
          borderColor: borderColor,
          textColor: textColor,
          subtextColor: subtextColor,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildReceivableActionCard({
    required OrderEntity order,
    required double dueAmount,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    final clientName = _getClientDisplayName(order);
    final shortId = order.id.length > 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$shortId',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clientName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DUE: ${CurrencyFormatter.formatWithLabel(dueAmount, 'NPR')}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.eventName} • ${formatNepaliDate(order.eventDate, 'yyyy-MM-dd')}',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_outlined,
                    size: 18, color: Color(0xFF25D366)),
                tooltip: 'Send WhatsApp Reminder',
                onPressed: () => _sendWhatsAppReminder(order),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.add_card, size: 14),
                label: const Text(
                  'Pay',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openPaymentDialog(order),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemCard({
    required OrderEntity order,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    final invNo = InvoiceSequenceService.generateSuggestedInvoiceNumber(
      isProforma: true,
      orderId: order.id,
      date: order.eventDate,
    );
    final dueAmount =
        (order.totalAmount - order.advanceReceived).clamp(0.0, double.infinity);
    final isPaid = dueAmount <= 0.01 && order.totalAmount > 0;
    final clientName = _getClientDisplayName(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      invNo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'DUE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  order.eventName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$clientName • Total: ${CurrencyFormatter.formatWithLabel(order.totalAmount, 'NPR')}',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Preview', style: TextStyle(fontSize: 11)),
                onPressed: () => _openInvoiceCustomizerDialog(
                  order,
                  isPreviewOnly: true,
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Send',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _openInvoiceCustomizerDialog(
                  order,
                  isPreviewOnly: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Event Selector Modal for Quick Invoice Generation ─────────────────────────

class _EventSelectorModal extends StatefulWidget {
  final List<OrderEntity> orders;
  final ValueChanged<OrderEntity> onSelect;

  const _EventSelectorModal({
    required this.orders,
    required this.onSelect,
  });

  @override
  State<_EventSelectorModal> createState() => _EventSelectorModalState();
}

class _EventSelectorModalState extends State<_EventSelectorModal> {
  String _filter = '';

  String _getClientDisplayName(OrderEntity order) {
    if (order.client.trim().isNotEmpty) {
      return order.client.trim();
    }
    if (order.contactPerson.trim().isNotEmpty) {
      return order.contactPerson.trim();
    }
    return order.eventName;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txtColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subColor = const Color(0xFF64748b);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);

    final filtered = widget.orders.where((o) {
      final q = _filter.toLowerCase().trim();
      if (q.isEmpty) return true;

      final cleanNoPrefix = q
          .replaceAll('#', '')
          .replaceAll('order-', '')
          .replaceAll('ord-', '')
          .replaceAll('order', '')
          .replaceAll('id:', '')
          .trim();

      final orderIdLower = o.id.toLowerCase();
      final isIdMatch = orderIdLower == q ||
          (cleanNoPrefix.isNotEmpty && orderIdLower.contains(cleanNoPrefix)) ||
          orderIdLower.contains(q);

      return isIdMatch ||
          o.eventName.toLowerCase().contains(q) ||
          o.client.toLowerCase().contains(q) ||
          o.venue.toLowerCase().contains(q) ||
          o.contactNumber.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Event to Generate Invoice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: txtColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              style: TextStyle(fontSize: 13, color: txtColor),
              decoration: InputDecoration(
                hintText: 'Search by Order ID (e.g. #123), event, or client...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => _filter = val.trim()),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching events or order IDs found.',
                        style: TextStyle(color: subColor),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: borderColor),
                      itemBuilder: (context, index) {
                        final o = filtered[index];
                        final shortId = o.id.length > 6
                            ? o.id.substring(0, 6).toUpperCase()
                            : o.id.toUpperCase();
                        final clientName = _getClientDisplayName(o);

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0075db)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#$shortId',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0075db),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  o.eventName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: txtColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '$clientName • ${formatNepaliDate(o.eventDate, 'yyyy-MM-dd')} • Total: ${CurrencyFormatter.formatWithLabel(o.totalAmount, 'NPR')}',
                              style: TextStyle(fontSize: 11, color: subColor),
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFF0075db)),
                          onTap: () => widget.onSelect(o),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manual Proforma Invoice Customizer Dialog ─────────────────────────────────

class InvoiceCustomizerModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final bool isPreviewDefault;

  const InvoiceCustomizerModal({
    super.key,
    required this.order,
    required this.isPreviewDefault,
  });

  @override
  ConsumerState<InvoiceCustomizerModal> createState() =>
      _InvoiceCustomizerModalState();
}

class _InvoiceCustomizerModalState
    extends ConsumerState<InvoiceCustomizerModal> {
  late TextEditingController _invNumberCtrl;
  late TextEditingController _buyerNameCtrl;
  late TextEditingController _buyerAddressCtrl;
  late TextEditingController _buyerVatCtrl;
  late TextEditingController _hsCodeCtrl;
  late TextEditingController _paymentTermsCtrl;
  late TextEditingController _advanceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _wordsCtrl;
  late DateTime _invoiceDate;
  final String _selectedInvoiceType = 'PROFORMA INVOICE';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultInvNo = InvoiceSequenceService.generateSuggestedInvoiceNumber(
      isProforma: true,
      orderId: widget.order.id,
      date: widget.order.eventDate,
    );
    _invNumberCtrl = TextEditingController(text: defaultInvNo);

    final clientName = widget.order.client.trim().isNotEmpty
        ? widget.order.client.trim()
        : (widget.order.contactPerson.trim().isNotEmpty
            ? widget.order.contactPerson.trim()
            : widget.order.eventName);

    _buyerNameCtrl = TextEditingController(text: clientName);
    _buyerAddressCtrl = TextEditingController(
      text: widget.order.venue.isNotEmpty
          ? widget.order.venue
          : 'Kathmandu, Nepal',
    );
    _buyerVatCtrl = TextEditingController();
    _hsCodeCtrl = TextEditingController();
    _paymentTermsCtrl = TextEditingController(text: 'Cash / Credit / Cheque');
    _advanceCtrl = TextEditingController(
      text: widget.order.advanceReceived > 0
          ? widget.order.advanceReceived.toStringAsFixed(2)
          : '0.00',
    );
    _discountCtrl = TextEditingController(
      text: widget.order.discount > 0
          ? widget.order.discount.toStringAsFixed(2)
          : '0.00',
    );
    _invoiceDate = DateTime.now();

    final defaultWords =
        NumberToWordsConverter.convertToRupees(widget.order.totalAmount);
    _wordsCtrl = TextEditingController(text: defaultWords);
  }

  @override
  void dispose() {
    _invNumberCtrl.dispose();
    _buyerNameCtrl.dispose();
    _buyerAddressCtrl.dispose();
    _buyerVatCtrl.dispose();
    _hsCodeCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _advanceCtrl.dispose();
    _discountCtrl.dispose();
    _wordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _processInvoice({required bool isPreview}) async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final allItems = await ref.read(allItemsStreamProvider.future);
      final allRevenue =
          await ref.read(allAdditionalRevenueStreamProvider.future);

      final orderItems =
          allItems.where((i) => i.orderId == widget.order.id).toList();
      final orderRevenue =
          allRevenue.where((r) => r.orderId == widget.order.id).toList();

      final parsedAdvance = double.tryParse(_advanceCtrl.text.trim()) ??
          widget.order.advanceReceived;
      final parsedDiscount =
          double.tryParse(_discountCtrl.text.trim()) ?? widget.order.discount;

      final pdfBytes = await OrderPdfService.generateInvoicePdf(
        order: widget.order,
        items: orderItems,
        additionalRevenue: orderRevenue,
        invoiceType: _selectedInvoiceType,
        companyName: 'Event Solution Pvt Ltd',
        companyAddress: 'Jwagal - 10, Lalitpur',
        companyPhone: 'Ph: 01-5268535, 01-5268103',
        companyVatNo: '601234567',
        buyerName: _buyerNameCtrl.text.trim(),
        buyerAddress: _buyerAddressCtrl.text.trim(),
        buyerVatNo: _buyerVatCtrl.text.trim(),
        paymentTerms: _paymentTermsCtrl.text.trim(),
        defaultHsCode: _hsCodeCtrl.text.trim(),
        discount: parsedDiscount,
        advanceReceived: parsedAdvance,
        invoiceNumber: _invNumberCtrl.text.trim(),
        invoiceDate: _invoiceDate,
        manualAmountInWords: _wordsCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // close dialog

      final invNo = _invNumberCtrl.text.trim();
      final fileName =
          '${invNo}_${widget.order.eventName.replaceAll(' ', '_')}.pdf';
      const subjectTitle = 'Proforma Invoice';

      if (isPreview) {
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfBytes,
          fileName: fileName,
          subject: '$subjectTitle: ${widget.order.eventName}',
        );
      } else {
        _showShareOptionsBottomSheet(
          pdfBytes: pdfBytes,
          fileName: fileName,
          invNo: invNo,
          invoiceType: _selectedInvoiceType,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error generating invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showShareOptionsBottomSheet({
    required Uint8List pdfBytes,
    required String fileName,
    required String invNo,
    String invoiceType = 'PROFORMA INVOICE',
  }) {
    const docTitle = 'Proforma Invoice';
    final clientName = _buyerNameCtrl.text.trim().isNotEmpty
        ? _buyerNameCtrl.text.trim()
        : 'Valued Client';
    final clientPhone =
        widget.order.contactNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final totalFormatted =
        CurrencyFormatter.formatWithLabel(widget.order.totalAmount, 'NPR');
    final parsedAdvance = double.tryParse(_advanceCtrl.text.trim()) ??
        widget.order.advanceReceived;
    final dueFormatted = CurrencyFormatter.formatWithLabel(
      (widget.order.totalAmount - parsedAdvance).clamp(0.0, double.infinity),
      'NPR',
    );

    final defaultMessage =
        'Dear $clientName,\n\nPlease find attached the $docTitle ($invNo) for ${widget.order.eventName}.\n\n'
        '• Event Date: ${formatNepaliDate(_invoiceDate, 'yyyy-MM-dd')}\n'
        '• Venue: ${_buyerAddressCtrl.text.trim()}\n'
        '• Payment Mode: ${_paymentTermsCtrl.text.trim()}\n'
        '• Total Amount: $totalFormatted\n'
        '• Balance Due: $dueFormatted\n\n'
        'Thank you for partnering with Event Solution Pvt Ltd!\nBest regards,\nFinance & Accounts Department';

    final messageCtrl = TextEditingController(text: defaultMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF1e293b) : Colors.white;
          final txtColor = isDark ? Colors.white : const Color(0xFF0f172a);

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.send_rounded,
                            color: Color(0xFF0075db)),
                        const SizedBox(width: 8),
                        Text(
                          'Send $docTitle to Client',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: txtColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(bottomCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$docTitle #$invNo • ${widget.order.eventName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageCtrl,
                  maxLines: 6,
                  style: TextStyle(fontSize: 13, color: txtColor),
                  decoration: InputDecoration(
                    labelText: 'Client Message Text',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (clientPhone.isNotEmpty) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            Navigator.pop(bottomCtx);
                            final encodedText =
                                Uri.encodeComponent(messageCtrl.text);
                            final cleanNumber = clientPhone.startsWith('+')
                                ? clientPhone.substring(1)
                                : (clientPhone.startsWith('977')
                                    ? clientPhone
                                    : '977$clientPhone');
                            final whatsappUrl = Uri.parse(
                              'https://wa.me/$cleanNumber?text=$encodedText',
                            );
                            if (await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(
                                whatsappUrl,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                            if (mounted) {
                              await ShareHelper.sharePdf(
                                context: context,
                                pdfBytes: pdfBytes,
                                fileName: fileName,
                                subject: '$docTitle: ${widget.order.eventName}',
                                message: messageCtrl.text,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0075db),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text(
                          'Share PDF',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          Navigator.pop(bottomCtx);
                          await ShareHelper.sharePdf(
                            context: context,
                            pdfBytes: pdfBytes,
                            fileName: fileName,
                            subject: '$docTitle: ${widget.order.eventName}',
                            message: messageCtrl.text,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final txtColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Generating Proforma Invoice...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0075db)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Color(0xFF0075db),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Proforma Invoice Configuration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: txtColor,
                                ),
                              ),
                              const Text(
                                'Event Solution Pvt Ltd • Jwagal - 10, Lalitpur',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748b),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),

                  // Scrollable Form Body
                  Expanded(
                    child: ListView(
                      children: [
                        // Row 1: Proforma Number & Date
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _invNumberCtrl,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: txtColor,
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'Proforma Number *',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _invoiceDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() => _invoiceDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatNepaliDate(
                                            _invoiceDate, 'yyyy-MM-dd'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: txtColor,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today,
                                          size: 16,
                                          color: Color(0xFF64748b)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Buyer's Name & Address
                        TextField(
                          controller: _buyerNameCtrl,
                          style: TextStyle(fontSize: 13, color: txtColor),
                          decoration: InputDecoration(
                            labelText: "Buyer's Name / Client *",
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _buyerAddressCtrl,
                          style: TextStyle(fontSize: 13, color: txtColor),
                          decoration: InputDecoration(
                            labelText: "Buyer's Address / Location",
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 3: Buyer's PAN/VAT & HS Code
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _buyerVatCtrl,
                                style: TextStyle(fontSize: 13, color: txtColor),
                                decoration: InputDecoration(
                                  labelText: "Buyer's PAN / VAT No.",
                                  hintText: 'e.g. 601234567',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _hsCodeCtrl,
                                style: TextStyle(fontSize: 13, color: txtColor),
                                decoration: InputDecoration(
                                  labelText: 'HS Code',
                                  hintText: 'Optional',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 4: Payment Terms (Cash / Credit / Cheque)
                        TextField(
                          controller: _paymentTermsCtrl,
                          style: TextStyle(fontSize: 13, color: txtColor),
                          decoration: InputDecoration(
                            labelText: 'Payment Terms / Mode',
                            hintText: 'Cash / Credit / Cheque',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 5: Advance Received & Discount
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _advanceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(fontSize: 13, color: txtColor),
                                decoration: InputDecoration(
                                  labelText: 'Advance Received (Rs.)',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (val) {
                                  final total = widget.order.totalAmount;
                                  _wordsCtrl.text =
                                      NumberToWordsConverter.convertToRupees(
                                          total);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _discountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: TextStyle(fontSize: 13, color: txtColor),
                                decoration: InputDecoration(
                                  labelText: 'Discount (Rs.)',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 6: Amount in Words (Editable)
                        TextField(
                          controller: _wordsCtrl,
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 12,
                              color: txtColor,
                              fontStyle: FontStyle.italic),
                          decoration: InputDecoration(
                            labelText: 'Amount in Words *',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 14),

                  // Bottom Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Preview PDF'),
                        onPressed: () => _processInvoice(isPreview: true),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0075db),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'Generate & Send',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _processInvoice(isPreview: false),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
