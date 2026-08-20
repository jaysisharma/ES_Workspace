import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/payment_receipt_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:uuid/uuid.dart';

class PaymentReceiptDialog extends ConsumerStatefulWidget {
  final OrderEntity order;

  const PaymentReceiptDialog({super.key, required this.order});

  @override
  ConsumerState<PaymentReceiptDialog> createState() =>
      _PaymentReceiptDialogState();
}

class _PaymentReceiptDialogState extends ConsumerState<PaymentReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _refNoCtrl;
  late TextEditingController _notesCtrl;
  String _selectedMode = 'Bank Transfer';
  late DateTime _paymentDate;
  bool _isSaving = false;

  final List<String> _paymentModes = [
    'Bank Transfer',
    'Fonepay / QR',
    'Cheque',
    'Cash',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final remainingDue =
        (widget.order.totalAmount - widget.order.advanceReceived)
            .clamp(0.0, double.infinity);
    _amountCtrl = TextEditingController(
      text: remainingDue > 0 ? remainingDue.toStringAsFixed(2) : '',
    );
    _refNoCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _paymentDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refNoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive payment amount.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final user = ref.read(authNotifierProvider).user;
      final receiptId = const Uuid().v4();

      final receipt = PaymentReceiptEntity(
        id: receiptId,
        orderId: widget.order.id,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMode: _selectedMode,
        referenceNo: _refNoCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        receivedBy: user?.email ?? 'Finance Dept',
        createdAt: DateTime.now(),
      );

      // 1. Save receipt document under orders/{orderId}/payments/{receiptId}
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('orders')
          .doc(widget.order.id)
          .collection('payments')
          .doc(receiptId)
          .set(receipt.toMap());

      // 2. Update Order total advanceReceived & add order log
      final updatedAdvance = widget.order.advanceReceived + amount;
      final logMessage =
          'Recorded payment receipt of ${CurrencyFormatter.formatWithLabel(amount, 'NPR')} via $_selectedMode (${receipt.referenceNo.isNotEmpty ? 'Ref: ${receipt.referenceNo}' : 'No Ref'})';

      final updatedLogs = List<OrderLogEntity>.from(widget.order.logs)
        ..add(OrderLogEntity(timestamp: DateTime.now(), message: logMessage));

      final updatedOrder = widget.order.copyWith(
        advanceReceived: updatedAdvance,
        advanceReferenceNo: receipt.referenceNo.isNotEmpty
            ? receipt.referenceNo
            : widget.order.advanceReferenceNo,
        logs: updatedLogs,
        updatedAt: DateTime.now(),
      );

      await ref.read(updateOrderUseCaseProvider).call(updatedOrder);
      ref.invalidate(ordersStreamProvider);

      if (!mounted) return;
      Navigator.pop(context, true);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '✅ Successfully recorded payment of ${CurrencyFormatter.formatWithLabel(amount, 'NPR')}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to record payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final txtColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subtextColor = const Color(0xFF64748b);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);

    final totalAmount = widget.order.totalAmount;
    final alreadyPaid = widget.order.advanceReceived;
    final currentDue = (totalAmount - alreadyPaid).clamp(0.0, double.infinity);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_card_rounded,
                          color: Colors.green,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record Payment Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: txtColor,
                            ),
                          ),
                          Text(
                            widget.order.eventName,
                            style: TextStyle(fontSize: 11, color: subtextColor),
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
              const SizedBox(height: 14),

              // Current Balance Due Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0f172a)
                      : const Color(0xFFf8fafc),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL INVOICED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatWithLabel(totalAmount, 'NPR'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: txtColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALREADY PAID',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatWithLabel(alreadyPaid, 'NPR'),
                          style: const TextStyle(
                            fontSize: 12,
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
                            fontWeight: FontWeight.bold,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatWithLabel(currentDue, 'NPR'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                currentDue > 0.01 ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Amount & Date
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: txtColor,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Payment Amount (Rs.) *',
                        prefixText: 'NPR ',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter amount';
                        }
                        if (double.tryParse(val) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _paymentDate = picked);
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatNepaliDate(_paymentDate, 'yyyy-MM-dd'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: txtColor,
                              ),
                            ),
                            const Icon(Icons.calendar_today,
                                size: 14, color: Color(0xFF64748b)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Payment Mode Dropdown & Ref No
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMode,
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: txtColor,
                          ),
                          items: _paymentModes
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMode = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _refNoCtrl,
                      style: TextStyle(fontSize: 13, color: txtColor),
                      decoration: InputDecoration(
                        labelText: 'Txn / Cheque / Ref No.',
                        hintText: 'e.g. TXN-99824',
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

              // Notes / Remarks
              TextFormField(
                controller: _notesCtrl,
                style: TextStyle(fontSize: 13, color: txtColor),
                decoration: InputDecoration(
                  labelText: 'Remarks / Notes (Optional)',
                  hintText: 'e.g. 2nd Installment received via Nabil Bank',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Payment Receipt',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSaving ? null : _submitPayment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
