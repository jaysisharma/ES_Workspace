import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:order_app/core/services/export_directory_service.dart';

class PdfExportHelper {
  /// Exports and shares or opens a PDF cleanly across all platforms (macOS, Windows, iOS, Android, Web)
  /// using ExportDirectoryService to save into configured destination and categorized subfolders.
  static Future<void> exportAndSharePdf({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String filename,
    bool forcePrintLayout = false,
    ExportCategory? category,
  }) async {
    final sanitizedFilename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    try {
      if (!kIsWeb) {
        // 1. Resolve destination directory using ExportDirectoryService (custom path + auto-arranged subfolders)
        final effectiveCategory = category ?? ExportDirectoryService.deduceCategory(filename);
        final targetDir = await ExportDirectoryService.resolveExportDirectory(category: effectiveCategory);

        final file = File('${targetDir.path}/$sanitizedFilename');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(pdfBytes);
        debugPrint('PdfExportHelper: PDF saved to file: ${file.path}');

        // 2. Open PDF with system viewer (e.g. macOS Preview, Android/iOS PDF viewer)
        final openResult = await OpenFilex.open(file.path);
        debugPrint('PdfExportHelper: OpenFilex result type: ${openResult.type}, message: ${openResult.message}');

        if (openResult.type != ResultType.done) {
          // Fallback to Printing sheet if OpenFilex fails
          unawaited(
            Printing.layoutPdf(
              onLayout: (format) async => pdfBytes,
              name: filename,
            ).catchError((e) {
              debugPrint('PdfExportHelper layoutPdf fallback error: $e');
              return false;
            }),
          );
        }
      } else {
        // Web platform layout / print
        unawaited(
          Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: filename,
          ),
        );
      }

      // 3. User feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF "$sanitizedFilename" opened successfully.'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PdfExportHelper: Error exporting PDF ($filename): $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        );
      }
    }
  }
}
