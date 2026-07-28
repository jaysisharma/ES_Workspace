import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/event_pass_entity.dart';
import './badge_service.dart';

class EventPassPdfService {
  static Future<void> generateAndPrintPassPdf(EventPassEntity pass) async {
    try {
      final template = await BadgeService.loadTemplate();
      if (template != null) {
        final badgePdf = await BadgeService.generateBadgePdf(pass, template);
        await Printing.layoutPdf(
          onLayout: (format) async => badgePdf.save(),
          name: 'EventPass_${pass.clientName.replaceAll(' ', '_')}.pdf',
        );
        return;
      }
    } catch (_) {
      // Fallback to standard layout on error
    }

    final pdf = pw.Document();
    final qrData = '{"id":"${pass.id}","sig":"${pass.passSignature}"}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 20),
                pw.Text(
                  'EVENT PASS',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 2, color: PdfColors.black, width: 150),
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CLIENT NAME',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          pass.clientName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Text(
                          'EVENT NAME',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          pass.eventName,
                          style: pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Text(
                          'CONTACT NUMBER',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          pass.clientPhone,
                          style: pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 140,
                          height: 140,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Scan in App to Redeem',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'AUTHORIZED SERVICES',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: pass.services.map((service) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(12),
                          ),
                        ),
                        child: pw.Text(
                          service.name,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Ticket ID: ${pass.id}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(pass.createdAt)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'EventPass_${pass.clientName.replaceAll(' ', '_')}.pdf',
    );
  }
}
