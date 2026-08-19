import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CompanyPdfGenerator {
  static Future<Uint8List> generateCompanyDetailsPdf({
    String companyName = 'ES Workspace',
    String tagline = 'Premier Event Management, Production & Equipment Solutions',
    String email = 'contact@esworkspace.com',
    String phone = '+977 980-0000000',
    String address = 'Kathmandu, Nepal',
    String website = 'https://esworkspace.com',
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    pw.Font? font;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {}

    final pdf = pw.Document(
      theme: (font != null && boldFont != null)
          ? pw.ThemeData.withFont(base: font, bold: boldFont)
          : null,
    );

    final isA5 = pageFormat.width < 500;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: isA5 ? const pw.EdgeInsets.all(20) : const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      tagline,
                      style: const pw.TextStyle(
                        color: PdfColors.blue100,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'OFFICIAL PROFILE',
                    style: pw.TextStyle(
                      color: PdfColors.blue800,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Company Overview Section
          pw.Text(
            '1. ABOUT ES WORKSPACE',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'ES Workspace is a leading full-service event management and technical production agency specializing in corporate galas, concerts, weddings, multi-stage festivals, and sports events. We provide end-to-end event planning, high-end audiovisual equipment rentals, stage lighting, and professional logistics management.',
            style: const pw.TextStyle(fontSize: 10, height: 1.4),
          ),

          pw.SizedBox(height: 16),

          // Core Services Grid / Table
          pw.Text(
            '2. CORE SERVICES OFFERED',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),

          pw.TableHelper.fromTextArray(
            headers: ['Service Category', 'Scope of Operations', 'Equipment & Capabilities'],
            data: [
              ['Technical Audio/Visual', 'Concerts, Speeches, Live Streaming', 'Line array speakers, digital mixers, wireless mics'],
              ['Stage & Lighting', 'Intelligent stage setups, LED walls', 'Moving heads, truss structures, P3/P4 LED panels'],
              ['Event Production', 'Decor, Seating, Flooring & Roofing', 'Custom stage designs, VIP lounges, security barricades'],
              ['Inventory & Logistics', 'Equipment rental & transport', 'Tracked inventory, warehouse dispatch, on-site engineers'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(6),
          ),

          pw.SizedBox(height: 20),

          // Contact & Bank Details
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CONTACT INFORMATION',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Address: $address', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Website: $website', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BANKING & REGISTRATION',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Account Name: ES Workspace Pvt. Ltd.', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Bank Name: Nabil Bank / NIC Asia', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Account No: 012010099887766', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('PAN / VAT No: 609876543', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // Standard Terms & Authorization Stamp
          pw.Text(
            '3. STANDARD TERMS & CONDITIONS',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Bullet(text: 'Quotations are valid for 30 days from issuance.', style: const pw.TextStyle(fontSize: 9)),
          pw.Bullet(text: 'A 50% advance confirmation deposit is required prior to equipment dispatch.', style: const pw.TextStyle(fontSize: 9)),
          pw.Bullet(text: 'All technical setups are inspected and operated by certified ES Workspace technicians.', style: const pw.TextStyle(fontSize: 9)),

          pw.SizedBox(height: 30),

          // Footer Stamp / Verification
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Synced & Secured via Synology NAS Storage System',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Generated: ${DateTime.now().toIso8601String().substring(0, 10)}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
