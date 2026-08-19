import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/number_to_words_converter.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:url_launcher/url_launcher.dart';

class EventInvoicesScreen extends ConsumerStatefulWidget {
  const EventInvoicesScreen({super.key});

  @override
  ConsumerState<EventInvoicesScreen> createState() =>
      _EventInvoicesScreenState();
}

class _EventInvoicesScreenState extends ConsumerState<EventInvoicesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'due', 'paid'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openInvoiceCustomizerDialog(OrderEntity order, {required bool isPreviewOnly}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _InvoiceCustomizerModal(
        order: order,
        isPreviewDefault: isPreviewOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor =
        isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf8fafc);
    final cardBg = isDarkMode ? const Color(0xFF1b262f) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF334155).withValues(alpha: 0.5)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final subtextColor = const Color(0xFF64748b);

    final ordersStream = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Tax Invoices & Billing',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: ordersStream.when(
        data: (orders) {
          final filtered = orders.where((o) {
            final query = _searchQuery.toLowerCase();
            final matchesQuery = query.isEmpty ||
                o.eventName.toLowerCase().contains(query) ||
                o.client.toLowerCase().contains(query) ||
                o.venue.toLowerCase().contains(query) ||
                o.id.toLowerCase().contains(query);

            if (!matchesQuery) return false;

            final due = o.totalAmount - o.advanceReceived;
            if (_statusFilter == 'due') {
              return due > 0.01;
            } else if (_statusFilter == 'paid') {
              return due <= 0.01 && o.totalAmount > 0;
            }
            return true;
          }).toList()
            ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

          // Compute Totals
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

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersStreamProvider);
                },
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    // Financial Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'TOTAL INVOICED',
                            amount: totalInvoiced,
                            icon: Icons.receipt_long,
                            color: primaryColor,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'TOTAL RECEIVED',
                            amount: totalAdvance,
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'RECEIVABLES DUE',
                            amount: totalDue,
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search & Filters Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(fontSize: 13, color: textColor),
                              decoration: InputDecoration(
                                hintText:
                                    'Search by client, event, invoice #...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: subtextColor,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 20,
                                  color: subtextColor,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val.trim()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filter Dropdown
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              icon: const Icon(Icons.filter_list, size: 18),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Status'),
                                ),
                                DropdownMenuItem(
                                  value: 'due',
                                  child: Text('Balance Due'),
                                ),
                                DropdownMenuItem(
                                  value: 'paid',
                                  child: Text('Paid in Full'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _statusFilter = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Invoices List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EVENT TAX INVOICES (${filtered.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: subtextColor.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No event invoices found matching criteria',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map((order) {
                        return _buildInvoiceCard(
                          order: order,
                          cardBg: cardBg,
                          borderColor: borderColor,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          primaryColor: primaryColor,
                        );
                      }),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              const BottomRightBackButton(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading events: $err'),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: subtextColor,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatWithLabel(amount, 'NPR'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard({
    required OrderEntity order,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    final invNo =
        'INV-${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}';
    final dueAmount =
        (order.totalAmount - order.advanceReceived).clamp(0.0, double.infinity);
    final isPaid = dueAmount <= 0.01 && order.totalAmount > 0;
    final isPartial = order.advanceReceived > 0 && dueAmount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Invoice Number, Date, Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        invNo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatNepaliDate(order.eventDate, 'yyyy-MM-dd'),
                      style: TextStyle(fontSize: 11, color: subtextColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.1)
                        : (isPartial
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid
                        ? 'PAID IN FULL'
                        : (isPartial ? 'PARTIAL' : 'UNPAID'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isPaid
                          ? Colors.green
                          : (isPartial ? Colors.orange : Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Event & Client Details
            Text(
              order.eventName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.business_outlined, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text(
                  order.client.isNotEmpty ? order.client : 'Individual Client',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
                if (order.venue.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.place_outlined, size: 14, color: subtextColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.venue,
                      style: TextStyle(fontSize: 12, color: subtextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),

            // Financial Summary Line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AMOUNT',
                      style: TextStyle(
                        fontSize: 9,
                        color: subtextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatWithLabel(order.totalAmount, 'NPR'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADVANCE PAID',
                      style: TextStyle(
                        fontSize: 9,
                        color: subtextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatWithLabel(
                          order.advanceReceived, 'NPR'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BALANCE DUE',
                      style: TextStyle(
                        fontSize: 9,
                        color: subtextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatWithLabel(dueAmount, 'NPR'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: dueAmount > 0.01 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Edit & Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    onPressed: () => _openInvoiceCustomizerDialog(
                      order,
                      isPreviewOnly: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text(
                      'Send Invoice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _openInvoiceCustomizerDialog(
                      order,
                      isPreviewOnly: false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manual Tax Invoice Customizer Dialog ──────────────────────────────────────

class _InvoiceCustomizerModal extends ConsumerStatefulWidget {
  final OrderEntity order;
  final bool isPreviewDefault;

  const _InvoiceCustomizerModal({
    required this.order,
    required this.isPreviewDefault,
  });

  @override
  ConsumerState<_InvoiceCustomizerModal> createState() =>
      _InvoiceCustomizerModalState();
}

class _InvoiceCustomizerModalState
    extends ConsumerState<_InvoiceCustomizerModal> {
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
  String _selectedInvoiceType = 'TAX INVOICE'; // 'TAX INVOICE' or 'PROFORMA INVOICE'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultInvNo =
        'INV-${widget.order.id.length > 8 ? widget.order.id.substring(0, 8).toUpperCase() : widget.order.id.toUpperCase()}';
    _invNumberCtrl = TextEditingController(text: defaultInvNo);
    _buyerNameCtrl = TextEditingController(
      text: widget.order.client.isNotEmpty
          ? widget.order.client
          : 'Valued Client',
    );
    _buyerAddressCtrl = TextEditingController(
      text: widget.order.venue.isNotEmpty
          ? widget.order.venue
          : 'Kathmandu, Nepal',
    );
    _buyerVatCtrl = TextEditingController();
    _hsCodeCtrl = TextEditingController(text: '998399');
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
        defaultHsCode: _hsCodeCtrl.text.trim().isNotEmpty
            ? _hsCodeCtrl.text.trim()
            : '998399',
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
      final isProforma = _selectedInvoiceType.toUpperCase().contains('PROFORMA');
      final subjectTitle = isProforma ? 'Proforma Invoice' : 'Tax Invoice';

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
    String invoiceType = 'TAX INVOICE',
  }) {
    final isProforma = invoiceType.toUpperCase().contains('PROFORMA');
    final docTitle = isProforma ? 'Proforma Invoice' : 'Tax Invoice';
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
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);

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
                      'Generating Official Invoice...',
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
                              color: const Color(0xFF0075db).withValues(alpha: 0.1),
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
                                'Invoice & Billing Configuration',
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
                        // Row 0: Invoice Type Toggle (TAX INVOICE vs PROFORMA INVOICE)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    setState(() {
                                      _selectedInvoiceType = 'TAX INVOICE';
                                      if (_invNumberCtrl.text.startsWith('PI-')) {
                                        _invNumberCtrl.text = _invNumberCtrl.text.replaceFirst('PI-', 'INV-');
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedInvoiceType == 'TAX INVOICE'
                                          ? const Color(0xFF0075db)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'TAX INVOICE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedInvoiceType == 'TAX INVOICE'
                                              ? Colors.white
                                              : const Color(0xFF64748b),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    setState(() {
                                      _selectedInvoiceType = 'PROFORMA INVOICE';
                                      if (_invNumberCtrl.text.startsWith('INV-')) {
                                        _invNumberCtrl.text = _invNumberCtrl.text.replaceFirst('INV-', 'PI-');
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _selectedInvoiceType == 'PROFORMA INVOICE'
                                          ? const Color(0xFF0075db)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'PROFORMA INVOICE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedInvoiceType == 'PROFORMA INVOICE'
                                              ? Colors.white
                                              : const Color(0xFF64748b),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 1: Invoice Number & Date
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
                                  labelText: _selectedInvoiceType == 'PROFORMA INVOICE'
                                      ? 'Proforma Number *'
                                      : 'Invoice Number *',
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
                                  hintText: '998399',
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
