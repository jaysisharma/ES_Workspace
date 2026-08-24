import 'package:pdf/widgets.dart' as pw;
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import '../pdf_data_models.dart';
import 'pdf_theme_and_styles.dart';

class PdfTablesBuilder {
  static List<pw.Widget> buildItemsTableWidgets(
    OrderEntity order,
    List<PdfItemData> items, {
    bool showFinancials = false,
    List<PdfRevenueData> additionalRevenue = const [],
    double managementCharge = 0.0,
    double managementChargeRate = 0.0,
    double discount = 0.0,
    double discountRate = 0.0,
    double? customVatRate,
    double advanceReceived = 0.0,
    String advanceReferenceNo = '',
  }) {
    final headers = showFinancials
        ? [
            'SN',
            'Vendor',
            'Item',
            'Qty',
            'Unit',
            'Type',
            'Days',
            'Rate',
            'Amount',
          ]
        : ['SN', 'Vendor', 'Item', 'Specification', 'Qty', 'Unit', 'Days'];
    final headerWidths = showFinancials
        ? [0.7, 1.8, 2.5, 0.8, 0.9, 1.0, 0.8, 1.4, 1.6]
        : [0.8, 2.2, 3.2, 2.2, 1.0, 1.0, 1.0];

    final double subtotal = showFinancials
        ? items.fold(0.0, (sum, item) => sum + item.amount) +
              additionalRevenue.fold(0.0, (sum, e) => sum + e.amount)
        : 0.0;

    final double computedMgtCharge = managementCharge > 0
        ? managementCharge
        : (managementChargeRate > 0
              ? (subtotal * managementChargeRate / 100)
              : 0.0);

    final double computedDiscount = discount > 0
        ? discount
        : (discountRate > 0 ? (subtotal * discountRate / 100) : 0.0);

    final double netTotal = subtotal + computedMgtCharge - computedDiscount;

    final double effectiveVatRate =
        (customVatRate != null && customVatRate >= 0)
        ? customVatRate
        : order.vatRate;

    final double computedVat = effectiveVatRate > 0.0001
        ? (netTotal * effectiveVatRate)
        : 0.0;

    final double grandTotal = netTotal + computedVat;

    final dataRows = <List<String>>[];
    int sn = 1;
    for (final item in items) {
      if (showFinancials) {
        dataRows.add([
          '${sn++}',
          item.vendor.isEmpty ? '-' : item.vendor,
          item.itemName,
          item.quantity.toString(),
          item.unit,
          item.billingType == 'daily' ? 'Daily' : 'Event',
          item.days.toString(),
          item.rate > 0 ? item.rate.toStringAsFixed(0) : '-',
          item.amount.toStringAsFixed(0),
        ]);
      } else {
        dataRows.add([
          '${sn++}',
          item.vendor.isEmpty ? '-' : item.vendor,
          item.itemName,
          item.specification,
          item.quantity.toString(),
          item.unit,
          item.days.toString(),
        ]);
      }
    }

    if (showFinancials && additionalRevenue.isNotEmpty) {
      for (final rev in additionalRevenue) {
        dataRows.add([
          '${sn++}',
          rev.vendorName.isEmpty ? '-' : rev.vendorName,
          rev.category == 'Other' && rev.description.isNotEmpty
              ? rev.description
              : rev.category,
          rev.quantity.toStringAsFixed(0),
          rev.unit,
          rev.billingType == 'daily' ? 'Daily' : 'Event',
          rev.days.toString(),
          rev.rate > 0 ? rev.rate.toStringAsFixed(0) : '-',
          rev.amount.toStringAsFixed(0),
        ]);
      }
    }

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(
          showFinancials ? 'REVENUE DETAILS' : 'ITEMS LIST',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfThemeAndStyles.darkColor,
            letterSpacing: 1.0,
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: dataRows,
        columnWidths: Map.fromIterables(
          List.generate(headers.length, (i) => i),
          headerWidths.map((w) => pw.FlexColumnWidth(w)),
        ),
        border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
        headerStyle: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfThemeAndStyles.darkColor,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: showFinancials
            ? {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              }
            : {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
              },
      ),
      if (showFinancials) ...[
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Column(
                children: [
                  PdfThemeAndStyles.summaryRow('SUBTOTAL', 'Rs. ${subtotal.toStringAsFixed(0)}'),
                  if (computedMgtCharge > 0)
                    PdfThemeAndStyles.summaryRow(
                      managementChargeRate > 0
                          ? 'MANAGEMENT CHARGE (${managementChargeRate.toStringAsFixed(0)}%)'
                          : 'MANAGEMENT CHARGE',
                      'Rs. ${computedMgtCharge.toStringAsFixed(0)}',
                    ),
                  if (computedDiscount > 0)
                    PdfThemeAndStyles.summaryRow(
                      discountRate > 0
                          ? 'DISCOUNT (${discountRate.toStringAsFixed(0)}%)'
                          : 'DISCOUNT',
                      '- Rs. ${computedDiscount.toStringAsFixed(0)}',
                    ),
                  PdfThemeAndStyles.summaryRow(
                    'TOTAL',
                    'Rs. ${netTotal.toStringAsFixed(0)}',
                    isBold: true,
                  ),
                  if (computedVat > 0)
                    PdfThemeAndStyles.summaryRow(
                      'VAT (${(effectiveVatRate * 100).toStringAsFixed(0)}%)',
                      'Rs. ${computedVat.toStringAsFixed(0)}',
                    ),
                  pw.Divider(color: PdfThemeAndStyles.borderColor, thickness: 1),
                  PdfThemeAndStyles.summaryRow(
                    'GRAND TOTAL',
                    'Rs. ${grandTotal.toStringAsFixed(0)}',
                    isBold: true,
                    fontSize: 10,
                  ),
                  if (advanceReceived > 0) ...[
                    PdfThemeAndStyles.summaryRow(
                      advanceReferenceNo.isNotEmpty
                          ? 'ADVANCE RECEIVED ($advanceReferenceNo)'
                          : 'ADVANCE RECEIVED',
                      '- Rs. ${advanceReceived.toStringAsFixed(0)}',
                    ),
                    pw.Divider(color: PdfThemeAndStyles.borderColor, thickness: 1),
                    PdfThemeAndStyles.summaryRow(
                      'BALANCE DUE',
                      'Rs. ${(grandTotal - advanceReceived).toStringAsFixed(0)}',
                      isBold: true,
                      fontSize: 10,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    ];
  }

  static List<pw.Widget> buildExpenseTableWidgets({
    required List<PdfItemData> itemRows,
    required List<PdfExpenseData> expenseRows,
  }) {
    final headers = [
      'SN',
      'Vendor',
      'Item',
      'Qty',
      'Unit',
      'Type',
      'Days',
      'Rate',
      'Amount',
    ];
    final headerWidths = [0.7, 1.8, 2.5, 0.8, 0.9, 1.0, 0.8, 1.4, 1.6];

    final vendorItemRows = itemRows.where((item) {
      final amt = item.vendorAmount > 0
          ? item.vendorAmount
          : (item.vendorRate *
                item.quantity *
                (item.billingType == 'daily' ? item.days : 1));
      return amt > 0 || item.vendor.isNotEmpty;
    }).toList();

    final double vendorTotal = vendorItemRows.fold(0.0, (sum, item) {
      final amt = item.vendorAmount > 0
          ? item.vendorAmount
          : (item.vendorRate *
                item.quantity *
                (item.billingType == 'daily' ? item.days : 1));
      return sum + amt;
    });

    final double operationalTotal = expenseRows.fold(
      0.0,
      (sum, exp) => sum + exp.amount,
    );

    final double totalExpenses = vendorTotal + operationalTotal;

    final dataRows = <List<String>>[];
    int sn = 1;
    for (final item in vendorItemRows) {
      final amt = item.vendorAmount > 0
          ? item.vendorAmount
          : (item.vendorRate *
                item.quantity *
                (item.billingType == 'daily' ? item.days : 1));
      dataRows.add([
        '${sn++}',
        item.vendor.isEmpty ? '-' : item.vendor,
        item.itemName,
        item.quantity.toString(),
        item.unit,
        item.billingType == 'daily' ? 'Daily' : 'Event',
        item.days.toString(),
        item.vendorRate > 0 ? item.vendorRate.toStringAsFixed(0) : '-',
        amt.toStringAsFixed(0),
      ]);
    }

    for (final expense in expenseRows) {
      dataRows.add([
        '${sn++}',
        expense.vendorName.isEmpty ? '-' : expense.vendorName,
        expense.category == 'Other' && expense.description.isNotEmpty
            ? expense.description
            : (expense.specification.isNotEmpty
                  ? '${expense.category} (${expense.specification})'
                  : expense.category),
        expense.quantity.toString(),
        expense.unit,
        expense.billingType == 'daily' ? 'Daily' : 'Event',
        expense.days.toString(),
        expense.rate > 0 ? expense.rate.toStringAsFixed(0) : '-',
        expense.amount.toStringAsFixed(0),
      ]);
    }

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(
          'EXPENSES DETAILS',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfThemeAndStyles.darkColor,
            letterSpacing: 1.0,
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: dataRows,
        columnWidths: Map.fromIterables(
          List.generate(headers.length, (i) => i),
          headerWidths.map((w) => pw.FlexColumnWidth(w)),
        ),
        border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
        headerStyle: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfThemeAndStyles.darkColor,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
          5: pw.Alignment.center,
          6: pw.Alignment.center,
          7: pw.Alignment.centerRight,
          8: pw.Alignment.centerRight,
        },
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: 240,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              children: [
                if (vendorTotal > 0 && operationalTotal > 0) ...[
                  PdfThemeAndStyles.summaryRow(
                    'VENDOR EXPENSES',
                    'Rs. ${vendorTotal.toStringAsFixed(0)}',
                  ),
                  PdfThemeAndStyles.summaryRow(
                    'OPERATIONAL EXPENSES',
                    'Rs. ${operationalTotal.toStringAsFixed(0)}',
                  ),
                  pw.Divider(color: PdfThemeAndStyles.borderColor, thickness: 0.5),
                ],
                PdfThemeAndStyles.summaryRow(
                  'TOTAL EXPENSES',
                  'Rs. ${totalExpenses.toStringAsFixed(0)}',
                  isBold: true,
                  fontSize: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  static pw.Widget buildGlobalFinancialSummaryCard(
    double totalRevenue,
    double totalExpenses,
    double netProfit,
    double margin, {
    double totalAdvance = 0.0,
    double totalDue = 0.0,
  }) {
    return PdfThemeAndStyles.card(
      title: 'GLOBAL FINANCIAL SUMMARY',
      child: pw.Column(
        children: [
          PdfThemeAndStyles.summarySummaryRow(
            'Total Revenue',
            'Rs. ${totalRevenue.toStringAsFixed(0)}',
          ),
          if (totalAdvance > 0) ...[
            pw.SizedBox(height: 4),
            PdfThemeAndStyles.summarySummaryRow(
              'Advance Received',
              'Rs. ${totalAdvance.toStringAsFixed(0)}',
            ),
          ],
          if (totalDue > 0) ...[
            pw.SizedBox(height: 4),
            PdfThemeAndStyles.summarySummaryRow(
              'Balance Due',
              'Rs. ${totalDue.toStringAsFixed(0)}',
            ),
          ],
          pw.SizedBox(height: 4),
          PdfThemeAndStyles.summarySummaryRow(
            'Total Expenses',
            'Rs. ${totalExpenses.toStringAsFixed(0)}',
          ),
          pw.SizedBox(height: 4),
          PdfThemeAndStyles.summarySummaryRow(
            'Net Profit',
            'Rs. ${netProfit.toStringAsFixed(0)}',
            isBold: true,
          ),
          pw.SizedBox(height: 4),
          PdfThemeAndStyles.summarySummaryRow('Profit Margin', '${margin.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  static pw.Widget buildOrdersFinancialTable(List<OrderEntity> orders) {
    final headers = [
      'Order ID',
      'Event Name',
      'Revenue',
      'Expenses',
      'Profit',
      'Advance',
      'Due',
    ];
    final headerWidths = [1.8, 3.8, 1.8, 1.8, 1.8, 1.8, 1.8];

    final data = orders.map((order) {
      final profit = order.totalAmount - order.totalExpenses;
      final due = (order.totalAmount - order.advanceReceived)
          .clamp(0.0, double.infinity);
      return [
        order.id,
        order.eventName,
        order.totalAmount.toStringAsFixed(0),
        order.totalExpenses.toStringAsFixed(0),
        profit.toStringAsFixed(0),
        order.advanceReceived.toStringAsFixed(0),
        due.toStringAsFixed(0),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      columnWidths: Map.fromIterables(
        List.generate(headers.length, (i) => i),
        headerWidths.map((w) => pw.FlexColumnWidth(w)),
      ),
      border: pw.TableBorder.all(
        color: PdfThemeAndStyles.borderColor,
        width: 0.5,
      ),
      headerStyle: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfThemeAndStyles.darkColor,
      ),
      headerDecoration:
          const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget buildPOTable(PurchaseOrderEntity po) {
    final headers = [
      'SN',
      'ITEM NAME',
      'SPECIFICATION',
      'QTY',
      'UNIT',
      'TYPE',
      'DAYS',
      'RATE',
      'TOTAL',
    ];
    final headerWidths = [0.8, 2.5, 2.5, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0];

    int sn = 1;
    final dataRows = po.items.map((item) {
      return [
        '${sn++}',
        item.itemName,
        item.specification,
        item.quantity.toString(),
        item.unit,
        item.billingType == 'daily' ? 'Daily' : 'Event',
        item.days.toString(),
        item.rate > 0 ? item.rate.toStringAsFixed(0) : '-',
        item.amount.toStringAsFixed(0),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: dataRows,
          columnWidths: Map.fromIterables(
            List.generate(headers.length, (i) => i),
            headerWidths.map((w) => pw.FlexColumnWidth(w)),
          ),
          border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfThemeAndStyles.darkColor,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
            6: pw.Alignment.center,
            7: pw.Alignment.centerRight,
            8: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              PdfThemeAndStyles.summaryRow(
                'SUBTOTAL',
                'Rs. ${po.totalAmount.toStringAsFixed(0)}',
              ),
              if (po.vatRate > 0.0001)
                PdfThemeAndStyles.summaryRow(
                  'VAT (${(po.vatRate * 100).toStringAsFixed(0)}%)',
                  'Rs. ${(po.totalAmount * po.vatRate).toStringAsFixed(0)}',
                ),
              pw.Divider(color: PdfThemeAndStyles.borderColor, thickness: 1),
              PdfThemeAndStyles.summaryRow(
                'GRAND TOTAL',
                'Rs. ${po.totalWithVat.toStringAsFixed(0)}',
                isBold: true,
                fontSize: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget buildSummaryCard(
    double itemsTotal,
    double manualTotal,
    double total,
  ) {
    return PdfThemeAndStyles.card(
      title: 'FINANCIAL SUMMARY',
      child: pw.Column(
        children: [
          PdfThemeAndStyles.summaryRow('Item Costs', 'Rs. ${itemsTotal.toStringAsFixed(0)}'),
          PdfThemeAndStyles.summaryRow(
            'Additional Expenses',
            'Rs. ${manualTotal.toStringAsFixed(0)}',
          ),
          pw.Divider(color: PdfThemeAndStyles.borderColor, thickness: 0.5),
          PdfThemeAndStyles.summaryRow(
            'GRAND TOTAL',
            'Rs. ${total.toStringAsFixed(0)}',
            isBold: true,
            fontSize: 10,
          ),
        ],
      ),
    );
  }
}
