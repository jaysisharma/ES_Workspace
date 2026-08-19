import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:order_app/core/utils/pdf_export_helper.dart';
import 'package:order_app/core/utils/share_helper.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List? pdfData;
  final FutureOr<Uint8List> Function(PdfPageFormat format)? buildPdf;
  final String title;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    this.pdfData,
    this.buildPdf,
    required this.title,
    required this.fileName,
  }) : assert(
          pdfData != null || buildPdf != null,
          'Either pdfData or buildPdf must be provided to PdfPreviewScreen',
        );

  Future<Uint8List> _getBytes() async {
    if (buildPdf != null) {
      return await buildPdf!(PdfPageFormat.a4);
    }
    return pdfData!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export & Save to Folder',
            onPressed: () async {
              try {
                final bytes = await _getBytes();
                if (context.mounted) {
                  await PdfExportHelper.exportAndSharePdf(
                    context: context,
                    pdfBytes: bytes,
                    filename: fileName,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to export PDF: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: () async {
              try {
                final bytes = await _getBytes();
                if (context.mounted) {
                  await ShareHelper.sharePdf(
                    context: context,
                    pdfBytes: bytes,
                    fileName: fileName,
                    subject: title,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to share PDF: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: colorScheme.outline, height: 1),
        ),
      ),
      body: PdfPreview(
        build: (format) async {
          Uint8List bytes;
          if (buildPdf != null) {
            bytes = await buildPdf!(format);
          } else {
            bytes = pdfData!;
          }
          if (bytes.isEmpty) {
            throw Exception('Generated PDF document is empty');
          }
          // Validate %PDF magic header bytes (%PDF -> [0x25, 0x50, 0x44, 0x46])
          if (bytes.length < 4 ||
              bytes[0] != 0x25 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x44 ||
              bytes[3] != 0x46) {
            throw Exception('Generated document is not a valid PDF file');
          }
          return bytes;
        },
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 54, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Unable to preview PDF document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        pdfFileName: fileName,
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: false,
        canChangeOrientation: false,
        canChangePageFormat: true,
        canDebug: false,
        maxPageWidth: 750,
      ),
    );
  }
}
