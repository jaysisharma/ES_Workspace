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

    int sn = 1;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: pw.Text(
                  h.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfThemeAndStyles.darkColor,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...items.map(
        (item) => pw.TableRow(
          children: showFinancials
              ? [
                  PdfThemeAndStyles.tableCell((sn++).toString(), align: pw.TextAlign.center),
                  PdfThemeAndStyles.tableCell(item.vendor.isEmpty ? '-' : item.vendor),
                  PdfThemeAndStyles.tableCell(item.itemName, bold: true),
                  PdfThemeAndStyles.tableCell(
                    item.quantity.toString(),
                    align: pw.TextAlign.center,
                  ),
                  PdfThemeAndStyles.tableCell(item.unit, align: pw.TextAlign.center),
                  PdfThemeAndStyles.tableCell(
                    item.billingType == 'daily' ? 'Daily' : 'Event',
                    align: pw.TextAlign.center,
                  ),
                  PdfThemeAndStyles.tableCell(item.days.toString(), align: pw.TextAlign.center),
                  PdfThemeAndStyles.tableCell(
                    item.rate.toStringAsFixed(0),
                    align: pw.TextAlign.right,
                  ),
                  PdfThemeAndStyles.tableCell(
                    item.amount.toStringAsFixed(0),
                    align: pw.TextAlign.right,
                  ),
                ]
              : [
                  PdfThemeAndStyles.tableCell((sn++).toString(), align: pw.TextAlign.center),
                  PdfThemeAndStyles.tableCell(item.vendor.isEmpty ? '-' : item.vendor),
                  PdfThemeAndStyles.tableCell(item.itemName, bold: true),
                  PdfThemeAndStyles.tableCell(item.specification),
                  PdfThemeAndStyles.tableCell(
                    item.quantity.toString(),
                    align: pw.TextAlign.center,
                  ),
                  PdfThemeAndStyles.tableCell(item.unit),
                  PdfThemeAndStyles.tableCell(item.days.toString(), align: pw.TextAlign.center),
                ],
        ),
      ),
      if (showFinancials && additionalRevenue.isNotEmpty)
        ...additionalRevenue.map(
          (rev) => pw.TableRow(
            children: [
              PdfThemeAndStyles.tableCell((sn++).toString(), align: pw.TextAlign.center),
              PdfThemeAndStyles.tableCell(rev.vendorName.isEmpty ? '-' : rev.vendorName),
              PdfThemeAndStyles.tableCell(
                rev.category == 'Other' && rev.description.isNotEmpty
                    ? rev.description
                    : rev.category,
                bold: true,
              ),
              PdfThemeAndStyles.tableCell(
                rev.quantity.toStringAsFixed(0),
                align: pw.TextAlign.center,
              ),
              PdfThemeAndStyles.tableCell(rev.unit, align: pw.TextAlign.center),
              PdfThemeAndStyles.tableCell(
                rev.billingType == 'daily' ? 'Daily' : 'Event',
                align: pw.TextAlign.center,
              ),
              PdfThemeAndStyles.tableCell(rev.days.toString(), align: pw.TextAlign.center),
              PdfThemeAndStyles.tableCell(
                rev.rate.toStringAsFixed(0),
                align: pw.TextAlign.right,
              ),
              PdfThemeAndStyles.tableCell(
                rev.amount.toStringAsFixed(0),
                align: pw.TextAlign.right,
              ),
            ],
          ),
        ),
    ];

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
      pw.Table(
        columnWidths: {
          for (int i = 0; i < headerWidths.length; i++)
            i: pw.FlexColumnWidth(headerWidths[i]),
        },
        border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
        children: rows,
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

    final double vendorTotal = itemRows.fold(0.0, (sum, item) {
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

    int sn = 1;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: pw.Text(
                  h.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfThemeAndStyles.darkColor,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...itemRows.map(
        (item) => pw.TableRow(
          children: [
            PdfThemeAndStyles.tableCell((sn++).toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(item.vendor.isEmpty ? '-' : item.vendor),
            PdfThemeAndStyles.tableCell(item.itemName, bold: true),
            PdfThemeAndStyles.tableCell(item.quantity.toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(item.unit, align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(
              item.billingType == 'daily' ? 'Daily' : 'Event',
              align: pw.TextAlign.center,
            ),
            PdfThemeAndStyles.tableCell(item.days.toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(
              item.vendorRate.toStringAsFixed(0),
              align: pw.TextAlign.right,
            ),
            PdfThemeAndStyles.tableCell(
              (item.vendorAmount > 0
                      ? item.vendorAmount
                      : (item.vendorRate *
                            item.quantity *
                            (item.billingType == 'daily' ? item.days : 1)))
                  .toStringAsFixed(0),
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ),
      ...expenseRows.map(
        (expense) => pw.TableRow(
          children: [
            PdfThemeAndStyles.tableCell((sn++).toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(expense.vendorName.isEmpty ? '-' : expense.vendorName),
            PdfThemeAndStyles.tableCell(
              expense.category == 'Other' && expense.description.isNotEmpty
                  ? expense.description
                  : (expense.specification.isNotEmpty
                        ? '${expense.category} (${expense.specification})'
                        : expense.category),
              bold: true,
            ),
            PdfThemeAndStyles.tableCell(expense.quantity.toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(expense.unit, align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(
              expense.billingType == 'daily' ? 'Daily' : 'Event',
              align: pw.TextAlign.center,
            ),
            PdfThemeAndStyles.tableCell(expense.days.toString(), align: pw.TextAlign.center),
            PdfThemeAndStyles.tableCell(
              expense.rate.toStringAsFixed(0),
              align: pw.TextAlign.right,
            ),
            PdfThemeAndStyles.tableCell(
              expense.amount.toStringAsFixed(0),
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ),
    ];

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
      pw.Table(
        columnWidths: {
          for (int i = 0; i < headerWidths.length; i++)
            i: pw.FlexColumnWidth(headerWidths[i]),
        },
        border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
        children: rows,
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
    double margin,
  ) {
    return PdfThemeAndStyles.card(
      title: 'GLOBAL FINANCIAL SUMMARY',
      child: pw.Column(
        children: [
          PdfThemeAndStyles.summarySummaryRow(
            'Total Revenue',
            'Rs. ${totalRevenue.toStringAsFixed(0)}',
          ),
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
    final headers = ['Order ID', 'Event Name', 'Revenue', 'Expenses', 'Profit'];
    final headerWidths = [2.0, 5.0, 2.0, 2.0, 2.0];

    return PdfThemeAndStyles.card(
      title: 'ORDER-WISE BREAKDOWN',
      child: pw.Table(
        columnWidths: {
          for (int i = 0; i < headerWidths.length; i++)
            i: pw.FlexColumnWidth(headerWidths[i]),
        },
        border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
            children: headers
                .map(
                  (h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: pw.Text(
                      h.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfThemeAndStyles.darkColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ...orders.map((order) {
            final profit = order.totalAmount - order.totalExpenses;
            return pw.TableRow(
              children: [
                PdfThemeAndStyles.tableCell(order.id, bold: true),
                PdfThemeAndStyles.tableCell(order.eventName),
                PdfThemeAndStyles.tableCell(order.totalAmount.toStringAsFixed(0)),
                PdfThemeAndStyles.tableCell(order.totalExpenses.toStringAsFixed(0)),
                PdfThemeAndStyles.tableCell(profit.toStringAsFixed(0)),
              ],
            );
          }),
        ],
      ),
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
    final List<pw.TableRow> rows = [];

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfThemeAndStyles.lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfThemeAndStyles.darkColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            )
            .toList(),
      ),
    );

    for (final item in po.items) {
      rows.add(
        pw.TableRow(
          children: [
            PdfThemeAndStyles.tableCell((sn++).toString()),
            PdfThemeAndStyles.tableCell(item.itemName, bold: true),
            PdfThemeAndStyles.tableCell(item.specification),
            PdfThemeAndStyles.tableCell(item.quantity.toString()),
            PdfThemeAndStyles.tableCell(item.unit),
            PdfThemeAndStyles.tableCell(item.billingType == 'daily' ? 'Daily' : 'Event'),
            PdfThemeAndStyles.tableCell(item.days.toString()),
            PdfThemeAndStyles.tableCell(item.rate.toStringAsFixed(0)),
            PdfThemeAndStyles.tableCell(item.amount.toStringAsFixed(0)),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Table(
          columnWidths: {
            for (int i = 0; i < headerWidths.length; i++)
              i: pw.FlexColumnWidth(headerWidths[i]),
          },
          border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
          children: rows,
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
