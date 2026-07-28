import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/badge_template_model.dart';
import '../../domain/entities/event_pass_entity.dart';

class BadgeService {
  static const String _storageKey = 'badge_template_config';

  // Save the template configuration
  static Future<bool> saveTemplate(BadgeTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_storageKey, template.toJson());
  }

  // Load the template configuration
  static Future<BadgeTemplate?> loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return null;
    try {
      return BadgeTemplate.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  // Delete the template configuration
  static Future<bool> deleteTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_storageKey);
  }

  // Generate the PDF representation of the badge
  static Future<pw.Document> generateBadgePdf(EventPassEntity pass, BadgeTemplate template) async {
    final pdf = pw.Document();
    
    // Convert mm dimensions to PostScript points (1 mm = 2.83465 points)
    final double widthPoints = template.widthMm * 2.83465;
    final double heightPoints = template.heightMm * 2.83465;
    
    // Read the background template image bytes
    final File imageFile = File(template.imagePath);
    if (!imageFile.existsSync()) {
      throw Exception('Card template image file not found at ${template.imagePath}');
    }
    
    final imageBytes = imageFile.readAsBytesSync();
    final pw.MemoryImage bgImage = pw.MemoryImage(imageBytes);
    
    // QR data matches order_app's signature verification format
    final String qrData = '{"id":"${pass.id}","sig":"${pass.passSignature}"}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(widthPoints, heightPoints, marginAll: 0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Background image template
              pw.Positioned.fill(
                child: pw.Image(bgImage, fit: pw.BoxFit.fill),
              ),
              
              // 2. Positioned QR code
              pw.Positioned(
                left: widthPoints * template.qrX,
                top: heightPoints * template.qrY,
                right: widthPoints * (template.qrX + template.qrSize),
                bottom: heightPoints * template.qrY + widthPoints * template.qrSize,
                child: pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.all(6), // small border/padding for contrast
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    drawText: false,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
