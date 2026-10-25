import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/inventory_entity.dart';

class InventoryExcelExportService {
  InventoryExcelExportService._();

  /// Exports all inventory items in a single comprehensive Excel worksheet.
  static Future<void> exportAllInventory({
    required BuildContext context,
    required List<InventoryItemEntity> items,
    String currencySymbol = 'NPR',
  }) async {
    final now = DateTime.now();
    final dateStr = formatNepaliDate(now, 'yyyy-MM-dd');
    final filename = 'Inventory_All_Items_$dateStr';

    final headers = [
      'Item No',
      'Category',
      'Item Name',
      'Specification',
      'Quantity',
      'Rate ($currencySymbol)',
      'Total ($currencySymbol)',
    ];

    final List<List<dynamic>> rows = [];
    int totalQty = 0;
    double grandTotal = 0.0;

    for (final item in items) {
      totalQty += item.quantity;
      grandTotal += item.total;
      rows.add([
        item.itemNo.isNotEmpty ? item.itemNo : '—',
        item.category,
        item.name,
        item.specification.isNotEmpty ? item.specification : '—',
        item.quantity,
        item.rate,
        item.total,
      ]);
    }

    // Append Summary / Grand Total Row
    rows.add([
      'TOTAL',
      '${items.length} items',
      '',
      '',
      totalQty,
      '',
      grandTotal,
    ]);

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: 'All Inventory',
      title: 'INVENTORY MASTER REGISTRY',
      category: ExportCategory.inventory,
    );
  }

  /// Exports a single filtered category to Excel
  static Future<void> exportCategoryInventory({
    required BuildContext context,
    required List<InventoryItemEntity> items,
    required String category,
    String currencySymbol = 'NPR',
  }) async {
    final now = DateTime.now();
    final dateStr = formatNepaliDate(now, 'yyyy-MM-dd');
    final safeCatName = category.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'Inventory_${safeCatName}_$dateStr';

    final categoryItems = category.toUpperCase() == 'ALL'
        ? items
        : items.where((i) => i.category.toLowerCase() == category.toLowerCase()).toList();

    final headers = [
      'Item No',
      'Category',
      'Item Name',
      'Specification',
      'Quantity',
      'Rate ($currencySymbol)',
      'Total ($currencySymbol)',
    ];

    final List<List<dynamic>> rows = [];
    int totalQty = 0;
    double grandTotal = 0.0;

    for (final item in categoryItems) {
      totalQty += item.quantity;
      grandTotal += item.total;
      rows.add([
        item.itemNo.isNotEmpty ? item.itemNo : '—',
        item.category,
        item.name,
        item.specification.isNotEmpty ? item.specification : '—',
        item.quantity,
        item.rate,
        item.total,
      ]);
    }

    rows.add([
      'TOTAL',
      '${categoryItems.length} items',
      '',
      '',
      totalQty,
      '',
      grandTotal,
    ]);

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: category.length > 25 ? category.substring(0, 25) : category,
      title: 'INVENTORY - ${category.toUpperCase()}',
      category: ExportCategory.inventory,
    );
  }

  /// Exports a multi-sheet Excel workbook:
  /// - Sheet 1: Master summary ("All Items")
  /// - Subsequent Sheets: One dedicated sheet per category with items and subtotals.
  static Future<void> exportCategoryWiseWorkbook({
    required BuildContext context,
    required List<InventoryItemEntity> items,
    String currencySymbol = 'NPR',
  }) async {
    final now = DateTime.now();
    final dateStr = formatNepaliDate(now, 'yyyy-MM-dd');
    final filename = 'Inventory_Category_Wise_$dateStr';

    final excel = Excel.createExcel();

    // Group items by category
    final Map<String, List<InventoryItemEntity>> grouped = {};
    for (final item in items) {
      final cat = item.category.trim().isEmpty ? 'General' : item.category.trim();
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    final sortedCategories = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    // 1. Build Master Sheet "All Items"
    _populateWorksheet(
      excel: excel,
      sheetName: 'All Items',
      title: 'INVENTORY MASTER REGISTRY',
      items: items,
      currencySymbol: currencySymbol,
    );

    // 2. Build one worksheet per category
    for (final cat in sortedCategories) {
      // Excel sheet names cannot exceed 31 chars and cannot contain: \ / ? * : [ ]
      var cleanSheetName = cat.replaceAll(RegExp(r'[\/\\?*:[\]]'), '_');
      if (cleanSheetName.length > 30) {
        cleanSheetName = cleanSheetName.substring(0, 30);
      }
      if (cleanSheetName.toLowerCase() == 'all items') {
        cleanSheetName = '$cleanSheetName (Cat)';
      }

      _populateWorksheet(
        excel: excel,
        sheetName: cleanSheetName,
        title: 'INVENTORY CATEGORY: ${cat.toUpperCase()}',
        items: grouped[cat]!,
        currencySymbol: currencySymbol,
      );
    }

    // If default Sheet1 was created and wasn't used, delete it
    if (excel.sheets.keys.contains('Sheet1') && !grouped.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    await ExcelExportHelper.saveAndShareWorkbook(
      context: context,
      excel: excel,
      filename: filename,
      category: ExportCategory.inventory,
    );
  }

  static void _populateWorksheet({
    required Excel excel,
    required String sheetName,
    required String title,
    required List<InventoryItemEntity> items,
    required String currencySymbol,
  }) {
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final rowEvenLeftStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final rowEvenRightStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final rowOddLeftStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final rowOddRightStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final totalsStyleLeft = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final totalsStyleRight = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Title
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue(title);
    titleCell.cellStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#1E293B'),
      bold: true,
      fontSize: 13,
    );

    // Subtitle
    final subCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    subCell.value = TextCellValue('Exported: ${DateTime.now().toString().substring(0, 19)} | Total Items: ${items.length}');
    subCell.cellStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('#64748B'),
      italic: true,
      fontSize: 9,
    );

    final headers = [
      'Item No',
      'Category',
      'Item Name',
      'Specification',
      'Quantity',
      'Rate ($currencySymbol)',
      'Total ($currencySymbol)',
    ];

    int curRow = 3;
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: curRow));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }
    curRow++;

    int totalQty = 0;
    double grandTotal = 0.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isEven = i % 2 == 0;
      final leftStyle = isEven ? rowEvenLeftStyle : rowOddLeftStyle;
      final rightStyle = isEven ? rowEvenRightStyle : rowOddRightStyle;

      totalQty += item.quantity;
      grandTotal += item.total;

      // Col 0: Item No
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: curRow));
      c0.value = TextCellValue(item.itemNo.isNotEmpty ? item.itemNo : '—');
      c0.cellStyle = leftStyle;

      // Col 1: Category
      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: curRow));
      c1.value = TextCellValue(item.category);
      c1.cellStyle = leftStyle;

      // Col 2: Item Name
      final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow));
      c2.value = TextCellValue(item.name);
      c2.cellStyle = leftStyle;

      // Col 3: Specification
      final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: curRow));
      c3.value = TextCellValue(item.specification.isNotEmpty ? item.specification : '—');
      c3.cellStyle = leftStyle;

      // Col 4: Quantity
      final c4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: curRow));
      c4.value = IntCellValue(item.quantity);
      c4.cellStyle = rightStyle;

      // Col 5: Rate
      final c5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: curRow));
      c5.value = DoubleCellValue(item.rate);
      c5.cellStyle = rightStyle;

      // Col 6: Total
      final c6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: curRow));
      c6.value = DoubleCellValue(item.total);
      c6.cellStyle = rightStyle;

      curRow++;
    }

    // Totals Row
    final t0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: curRow));
    t0.value = TextCellValue('TOTAL');
    t0.cellStyle = totalsStyleLeft;

    final t1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: curRow));
    t1.value = TextCellValue('${items.length} items');
    t1.cellStyle = totalsStyleLeft;

    final t2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: curRow));
    t2.value = TextCellValue('');
    t2.cellStyle = totalsStyleLeft;

    final t3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: curRow));
    t3.value = TextCellValue('');
    t3.cellStyle = totalsStyleLeft;

    final t4 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: curRow));
    t4.value = IntCellValue(totalQty);
    t4.cellStyle = totalsStyleRight;

    final t5 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: curRow));
    t5.value = TextCellValue('');
    t5.cellStyle = totalsStyleRight;

    final t6 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: curRow));
    t6.value = DoubleCellValue(grandTotal);
    t6.cellStyle = totalsStyleRight;

    // Set column widths
    sheet.setColumnWidth(0, 16.0); // Item No
    sheet.setColumnWidth(1, 18.0); // Category
    sheet.setColumnWidth(2, 28.0); // Item Name
    sheet.setColumnWidth(3, 30.0); // Specification
    sheet.setColumnWidth(4, 14.0); // Quantity
    sheet.setColumnWidth(5, 16.0); // Rate
    sheet.setColumnWidth(6, 18.0); // Total
  }
}
