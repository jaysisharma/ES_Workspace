import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: colorScheme.outline, height: 1),
        ),
      ),
      body: PdfPreview(
        build: (format) async {
          if (buildPdf != null) {
            return await buildPdf!(format);
          }
          return pdfData!;
        },
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
