import 'package:flutter/material.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';

class FinanceExcelExportService {
  FinanceExcelExportService._();

  /// Exports the Invoices & Billing registry to an Excel spreadsheet
  static Future<void> exportInvoicesRegistry({
    required BuildContext context,
    required List<OrderEntity> orders,
    String? filterStatus,
  }) async {
    final now = DateTime.now();
    final dateStr = formatNepaliDate(now, 'yyyy-MM-dd');
    final filename = 'ES_Invoices_Registry_$dateStr';

    final headers = [
      'S.N.',
      'Proforma Invoice Number',
      'Event Name',
      'Client Name',
      'Event Date (BS)',
      'Venue',
      'Total Amount (NPR)',
      'Advance Received (NPR)',
      'Balance Due (NPR)',
      'Payment Status',
    ];

    final List<List<dynamic>> rows = [];
    int sn = 1;
    double totalInvoicedSum = 0.0;
    double totalAdvanceSum = 0.0;
    double totalDueSum = 0.0;

    int extractOrderNum(String id) {
      final match = RegExp(r'\d+').firstMatch(id);
      return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    }

    final sortedOrders = List<OrderEntity>.from(orders)
      ..sort((a, b) {
        final numA = extractOrderNum(a.id);
        final numB = extractOrderNum(b.id);
        if (numA != 0 && numB != 0 && numA != numB) {
          return numA.compareTo(numB);
        }
        return a.id.compareTo(b.id);
      });

    for (final order in sortedOrders) {
      final due = (order.totalAmount - order.advanceReceived).clamp(0.0, double.infinity);
      final isPaid = due <= 0.01 && order.totalAmount > 0;
      final isPartial = order.advanceReceived > 0 && due > 0;
      final statusStr = isPaid ? 'PAID IN FULL' : (isPartial ? 'PARTIAL PAYMENT' : 'UNPAID / DUE');

      final invNo = 'PI-${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}';
      final clientName = order.client.isNotEmpty
          ? order.client
          : (order.contactPerson.isNotEmpty
              ? order.contactPerson
              : order.eventName);

      totalInvoicedSum += order.totalAmount;
      totalAdvanceSum += order.advanceReceived;
      totalDueSum += due;

      rows.add([
        sn++,
        invNo,
        order.eventName,
        clientName,
        formatNepaliDate(order.eventDate, 'yyyy-MM-dd'),
        order.venue.isNotEmpty ? order.venue : 'Kathmandu, Nepal',
        order.totalAmount,
        order.advanceReceived,
        due,
        statusStr,
      ]);
    }

    // Add empty row and Summary row
    rows.add(['', '', '', '', '', '', '', '', '', '']);
    rows.add([
      'TOTAL',
      '',
      '${orders.length} Invoices',
      '',
      '',
      '',
      totalInvoicedSum,
      totalAdvanceSum,
      totalDueSum,
      '',
    ]);

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: 'Invoices Registry',
      title: 'EVENT SOLUTION PVT LTD - INVOICES & BILLING REGISTRY ($dateStr)',
    );
  }

  /// Exports the Financial Ledger to an Excel spreadsheet
  static Future<void> exportFinancialLedger({
    required BuildContext context,
    required List<Map<String, dynamic>> ledgerEntries,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    String periodTitle = '',
  }) async {
    final now = DateTime.now();
    final dateStr = formatNepaliDate(now, 'yyyy-MM-dd');
    final filename = 'ES_Financial_Ledger_$dateStr';

    final headers = [
      'S.N.',
      'Date (BS)',
      'Transaction Entity / Details',
      'Category / Event',
      'Inflow / Revenue (NPR)',
      'Outflow / Expense (NPR)',
      'Net Balance (NPR)',
    ];

    final List<List<dynamic>> rows = [];
    int sn = 1;

    for (final entry in ledgerEntries) {
      final date = entry['date'] as DateTime? ?? DateTime.now();
      final entity = entry['entity']?.toString() ?? '';
      final category = entry['category']?.toString() ?? '';
      final revenue = (entry['revenue'] as num?)?.toDouble() ?? 0.0;
      final expense = (entry['expense'] as num?)?.toDouble() ?? 0.0;
      final balance = (entry['balance'] as num?)?.toDouble() ?? 0.0;

      rows.add([
        sn++,
        formatNepaliDate(date, 'yyyy-MM-dd'),
        entity,
        category,
        revenue > 0 ? revenue : '',
        expense > 0 ? expense : '',
        balance,
      ]);
    }

    rows.add(['', '', '', '', '', '', '']);
    rows.add([
      'SUMMARY',
      '',
      'Total Transactions: ${ledgerEntries.length}',
      '',
      totalRevenue,
      totalExpenses,
      netBalance,
    ]);

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: 'Financial Ledger',
      title: 'EVENT SOLUTION PVT LTD - FINANCIAL LEDGER $periodTitle ($dateStr)',
    );
  }
}
