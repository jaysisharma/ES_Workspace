import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:order_app/core/services/export_directory_service.dart';

class ExcelExportHelper {
  /// Exports and opens/shares an Excel spreadsheet cleanly across all platforms
  /// using OpenFilex on desktop, and Share.shareXFiles on mobile to let users download/save.
  /// Automatically arranges files into categorized destination subfolders if configured.
  static Future<void> exportAndShareExcel({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String filename,
    String sheetName = 'Sheet1',
    String? title,
    ExportCategory? category,
  }) async {
    // Sanitize filename to remove special characters like &, %, $, #, spaces, etc.
    final rawName = filename.endsWith('.xlsx')
        ? filename.substring(0, filename.length - 5)
        : filename;
    final cleanName = rawName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final sanitizedFilename = '$cleanName.xlsx';

    try {
      final excel = Excel.createExcel();
      final sheet = excel[sheetName];

      // Remove default Sheet1 if name is custom
      if (excel.sheets.keys.contains('Sheet1') && sheetName != 'Sheet1') {
        excel.delete('Sheet1');
      }

      // ── Define Styles ────────────────────────────────────────────────────────
      final headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#1E293B'), // Dark Slate Blue / Grey
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),       // White
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
        backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'), // Slate 50 (Very light grey-blue)
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
        backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'), // Slate 100
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

      int startRow = 0;
      if (title != null) {
        // Write Title
        final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
        titleCell.value = TextCellValue(title.toUpperCase());
        titleCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#1E293B'),
          bold: true,
          fontSize: 14,
        );

        // Write Subtitle / Meta info
        final subtitleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
        subtitleCell.value = TextCellValue('Generated: ${DateTime.now().toString().substring(0, 19)}');
        subtitleCell.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#64748B'),
          italic: true,
          fontSize: 9,
        );

        startRow = 3; // Leave row 2 empty, start headers at row 3
      }

      // ── Populate Headers ─────────────────────────────────────────────────────
      for (int colIndex = 0; colIndex < headers.length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: startRow));
        cell.value = TextCellValue(headers[colIndex]);
        cell.cellStyle = headerStyle;
      }

      // ── Populate Rows ────────────────────────────────────────────────────────
      int rowIndex = startRow + 1;
      for (final row in rows) {
        final isTotalsRow = row.isNotEmpty && 
            row.first != null && 
            row.first.toString().toUpperCase().contains('TOTAL');

        for (int colIndex = 0; colIndex < row.length; colIndex++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
          final val = row[colIndex];

          // Write Cell Value
          if (val == null) {
            cell.value = TextCellValue('');
          } else if (val is int) {
            cell.value = IntCellValue(val);
          } else if (val is double) {
            cell.value = DoubleCellValue(val);
          } else if (val is bool) {
            cell.value = BoolCellValue(val);
          } else {
            cell.value = TextCellValue(val.toString());
          }

          // Apply Styles based on row/data type
          if (isTotalsRow) {
            cell.cellStyle = (val is num) ? totalsStyleRight : totalsStyleLeft;
          } else {
            final isEven = (rowIndex - startRow) % 2 == 0;
            if (isEven) {
              cell.cellStyle = (val is num) ? rowEvenRightStyle : rowEvenLeftStyle;
            } else {
              cell.cellStyle = (val is num) ? rowOddRightStyle : rowOddLeftStyle;
            }
          }
        }
        rowIndex++;
      }

      // ── Auto-adjust Column Widths ────────────────────────────────────────────
      for (int colIndex = 0; colIndex < headers.length; colIndex++) {
        int maxLen = headers[colIndex].length;
        for (final row in rows) {
          if (colIndex < row.length) {
            final cellText = row[colIndex]?.toString() ?? '';
            if (cellText.length > maxLen) {
              maxLen = cellText.length;
            }
          }
        }
        // Apply calculated width with padding, clamped between 12 and 40 characters
        sheet.setColumnWidth(colIndex, (maxLen + 4).toDouble().clamp(12.0, 40.0));
      }

      // Generate file bytes
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel bytes');
      }

      // Calculate share origin synchronously from context before async gaps
      Rect? sharePositionOrigin;
      try {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
          final position = box.localToGlobal(Offset.zero);
          sharePositionOrigin = position & box.size;
        }
      } catch (_) {}
      if (sharePositionOrigin == null || sharePositionOrigin.isEmpty) {
        try {
          final size = MediaQuery.of(context).size;
          sharePositionOrigin = Rect.fromLTWH(0, 0, size.width, size.height / 2);
        } catch (_) {
          sharePositionOrigin = const Rect.fromLTWH(0, 0, 100, 100);
        }
      }

      if (!kIsWeb) {
        // Resolve target directory using ExportDirectoryService (supports custom destination folder & auto-arranged category subfolders)
        final effectiveCategory = category ?? ExportDirectoryService.deduceCategory(filename);
        final targetDir = await ExportDirectoryService.resolveExportDirectory(
          category: effectiveCategory,
          filename: sanitizedFilename,
        );

        final file = File('${targetDir.path}/$sanitizedFilename');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(fileBytes);

        debugPrint('ExcelExportHelper: Saved Excel file to ${file.path}');

        final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

        if (isDesktop) {
          bool opened = false;

          if (Platform.isMacOS) {
            try {
              final res = await Process.run('open', [file.path]);
              if (res.exitCode == 0) {
                opened = true;
                debugPrint('ExcelExportHelper: Opened Excel file via macOS native open command');
              }
            } catch (e) {
              debugPrint('ExcelExportHelper: macOS open process error: $e');
            }
          } else if (Platform.isWindows) {
            try {
              final res = await Process.run('cmd', ['/c', 'start', '', file.path], runInShell: true);
              if (res.exitCode == 0) {
                opened = true;
              }
            } catch (_) {}
          } else if (Platform.isLinux) {
            try {
              final res = await Process.run('xdg-open', [file.path]);
              if (res.exitCode == 0) {
                opened = true;
              }
            } catch (_) {}
          }

          if (!opened) {
            final openResult = await OpenFilex.open(file.path);
            debugPrint('ExcelExportHelper: OpenFilex result: type=${openResult.type}, message=${openResult.message}');
            if (openResult.type == ResultType.done) {
              opened = true;
            }
          }

          if (!opened) {
            // Desktop fallback: allow user to pick location to save file instead of calling Share.shareXFiles
            final outputPath = await FilePicker.platform.saveFile(
              dialogTitle: 'Save Excel Spreadsheet',
              fileName: sanitizedFilename,
              type: FileType.custom,
              allowedExtensions: ['xlsx'],
            );
            if (outputPath != null) {
              final outFile = File(outputPath);
              await outFile.writeAsBytes(fileBytes, flush: true);
              debugPrint('ExcelExportHelper: Saved Excel to $outputPath');
            }
          }
        } else {
          // Mobile platforms (iOS, Android) - trigger share sheet to allow "Save to Files" (download)
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
            text: sanitizedFilename,
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel "$sanitizedFilename" saved successfully.'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('ExcelExportHelper: Error exporting Excel ($filename): $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate Excel: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        );
      }
    }
  }
}
