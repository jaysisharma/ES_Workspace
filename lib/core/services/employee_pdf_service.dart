import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import '../utils/nepali_date_formatter.dart';

class EmployeePdfService {
  static Future<Uint8List> generateEmployeeDetailPdf({
    required EmployeeProfileEntity profile,
    UserEntity? user,
    Uint8List? photoBytes,
    String companyName = 'EVENT SOLUTION',
    String companyTagline = '',
    String companyAddress = '',
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

    pw.MemoryImage? companyLogoImage;
    try {
      final logoData = await rootBundle.load('assets/images/event_solution_logo.jpeg');
      companyLogoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      try {
        final logoData = await rootBundle.load('assets/ESWORKSPACE_app/event_solution_logo.jpeg');
        companyLogoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    pw.MemoryImage? profileImage;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        profileImage = pw.MemoryImage(photoBytes);
      } catch (_) {}
    } else if (profile.photoUrl != null && profile.photoUrl!.trim().isNotEmpty) {
      try {
        final url = profile.photoUrl!.trim();
        if (url.startsWith('http://') || url.startsWith('https://')) {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            profileImage = pw.MemoryImage(res.bodyBytes);
          }
        } else if (url.startsWith('data:image')) {
          final base64Str = url.split(',').last;
          final bytes = base64.decode(base64Str);
          profileImage = pw.MemoryImage(bytes);
        } else {
          final file = File(url);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            profileImage = pw.MemoryImage(bytes);
          }
        }
      } catch (_) {}
    }

    final joiningDateStr = formatNepaliDate(profile.officeJoinDate, 'yyyy-MM-dd');
    final dobStr = profile.dob != null ? formatNepaliDate(profile.dob!, 'yyyy-MM-dd') : 'N/A';
    final leavingDateStr = profile.officeLeavingDate != null
        ? formatNepaliDate(profile.officeLeavingDate!, 'yyyy-MM-dd')
        : 'Currently Employed';

    final isA5 = pageFormat.width < 500;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: isA5 ? const pw.EdgeInsets.all(20) : const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ── Top Company Brand Header with Logo ───────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (companyLogoImage != null) ...[
                        pw.Container(
                          width: 44,
                          height: 44,
                          margin: const pw.EdgeInsets.only(right: 12),
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(
                              companyLogoImage,
                              width: 44,
                              height: 44,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            companyName,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          if (companyTagline.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              companyTagline,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                          if (companyAddress.isNotEmpty) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              companyAddress,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'EMPLOYEE RECORD',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Top Summary Header ──────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 54,
                    height: 54,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      shape: pw.BoxShape.circle,
                    ),
                    child: profileImage != null
                        ? pw.ClipOval(
                            child: pw.Image(
                              profileImage,
                              width: 54,
                              height: 54,
                              fit: pw.BoxFit.cover,
                            ),
                          )
                        : pw.Center(
                            child: pw.Text(
                              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'E',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile.name,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Designation: ${profile.designation.isNotEmpty ? profile.designation : "Staff Member"}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Role: ${user?.role.name.toUpperCase() ?? "STAFF"}  |  Status: ${user?.isActive == false ? "INACTIVE" : "ACTIVE & CONFIRMED"}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Section 1: Employment Details ────────────────────────────────
            _buildSectionTitle('1. EMPLOYMENT & BASIC DETAILS'),
            pw.SizedBox(height: 6),
            _buildInfoGrid([
              _GridItem('Employee Name', profile.name),
              _GridItem('Designation', profile.designation.isNotEmpty ? profile.designation : 'Staff Member'),
              _GridItem('Date of Joining', joiningDateStr),
              _GridItem('Employment Status', leavingDateStr),
            ]),
            pw.SizedBox(height: 14),

            // ── Section 2: Personal & Family Information ──────────────────────
            _buildSectionTitle('2. PERSONAL & FAMILY INFORMATION'),
            pw.SizedBox(height: 6),
            _buildInfoGrid([
              _GridItem('Date of Birth (DOB)', dobStr),
              _GridItem('Blood Group', profile.bloodGroup.isNotEmpty ? profile.bloodGroup : 'N/A'),
              _GridItem('Father\'s Name', profile.fatherName.isNotEmpty ? profile.fatherName : 'N/A'),
              _GridItem('Mother\'s Name', profile.motherName.isNotEmpty ? profile.motherName : 'N/A'),
              _GridItem('Grandfather\'s Name', profile.grandfatherName.isNotEmpty ? profile.grandfatherName : 'N/A'),
              _GridItem('Permanent Address', profile.address.isNotEmpty ? profile.address : 'N/A'),
            ]),
            pw.SizedBox(height: 14),

            // ── Section 3: Official Identification Numbers ─────────────────────
            _buildSectionTitle('3. GOVT IDENTIFICATION & DOCUMENTS'),
            pw.SizedBox(height: 6),
            _buildInfoGrid([
              _GridItem('Citizenship Number', profile.citizenshipNumber.isNotEmpty ? profile.citizenshipNumber : 'N/A'),
              _GridItem('PAN Card Number', profile.panNumber.isNotEmpty ? profile.panNumber : 'N/A'),
              _GridItem('National Identity (NIN)', profile.ninNumber.isNotEmpty ? profile.ninNumber : 'N/A'),
            ]),
            pw.SizedBox(height: 14),

            // ── Section 4: Compensation & Payroll Breakdown ────────────────────
            _buildSectionTitle('4. COMPENSATION & PAYROLL BREAKDOWN'),
            pw.SizedBox(height: 6),
            () {
              final gross = profile.grossSalary;
              final tdsPct = gross > 0 ? (profile.tds / gross * 100) : 0.0;

              return pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  _buildTableRow('Basic Monthly Salary', 'NPR ${profile.basicSalary.toStringAsFixed(0)}'),
                  if (profile.fuelAllowance > 0)
                    _buildTableRow('Fuel Allowance', 'NPR ${profile.fuelAllowance.toStringAsFixed(0)}'),
                  if (profile.communicationAllowance > 0)
                    _buildTableRow('Communication Allowance', 'NPR ${profile.communicationAllowance.toStringAsFixed(0)}'),
                  if (profile.dearnessAllowance > 0)
                    _buildTableRow('Dearness / Travel Allowance', 'NPR ${profile.dearnessAllowance.toStringAsFixed(0)}'),
                  if (profile.bonus > 0)
                    _buildTableRow('Performance Bonus / Incentives', 'NPR ${profile.bonus.toStringAsFixed(0)}'),
                  _buildTableRow('Gross Salary', 'NPR ${profile.grossSalary.toStringAsFixed(0)}', isBold: true),
                  _buildTableRow('SSF Contribution (Social Security)', 'NPR ${profile.ssf.toStringAsFixed(0)}', isDeduction: true),
                  if (profile.effectiveLifeInsurance > 0)
                    _buildTableRow('Life Insurance Premium', 'NPR ${profile.effectiveLifeInsurance.toStringAsFixed(0)}', isDeduction: true),
                  if (profile.effectiveHealthInsurance > 0)
                    _buildTableRow('Health Insurance Premium', 'NPR ${profile.effectiveHealthInsurance.toStringAsFixed(0)}', isDeduction: true),
                  if (profile.cit > 0)
                    _buildTableRow('Citizen Investment Trust (CIT)', 'NPR ${profile.cit.toStringAsFixed(0)}', isDeduction: true),
                  if (profile.tds > 0)
                    _buildTableRow('Tax Deducted at Source (TDS)', 'NPR ${profile.tds.toStringAsFixed(0)}${tdsPct > 0 ? ' (${tdsPct.toStringAsFixed(1)}%)' : ''}', isDeduction: true),
                  _buildTableRow('NET PAYABLE MONTHLY SALARY (IN HAND)', 'NPR ${profile.netSalary.toStringAsFixed(0)}', isHeader: true),
                ],
              );
            }(),
            pw.SizedBox(height: 14),

            // ── Section 5: Leave Allocations ─────────────────────────────────
            _buildSectionTitle('5. ANNUAL LEAVE ENTITLEMENTS'),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: profile.effectiveAllowedLeaves.entries.map((e) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Text(
                    '${e.key}: ${e.value} Days',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 24),

            // ── Signatures & Authorization Box ──────────────────────────────
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(
                      width: 140,
                      height: 1,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Employee Signature',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(
                      width: 140,
                      height: 1,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'HR / Authorized Signatory',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'This document is an officially generated HR record of $companyName.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateStaffListPdf({
    required List<EmployeeProfileEntity> profiles,
    List<UserEntity> users = const [],
    String companyName = 'EVENT SOLUTION',
    PdfPageFormat? pageFormat,
  }) async {
    pw.Font? font;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      font = pw.Font.ttf(fontData);
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {}

    pw.MemoryImage? companyLogoImage;
    try {
      final logoData = await rootBundle.load('assets/images/event_solution_logo.jpeg');
      companyLogoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      try {
        final logoData = await rootBundle.load('assets/ESWORKSPACE_app/event_solution_logo.jpeg');
        companyLogoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    final pdf = pw.Document(
      theme: (font != null && boldFont != null)
          ? pw.ThemeData.withFont(base: font, bold: boldFont)
          : null,
    );
    final targetFormat = pageFormat ?? PdfPageFormat.a4.landscape;

    final userMap = {for (var u in users) u.id: u};
    final isA5 = targetFormat.width < 500;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: targetFormat,
        margin: isA5 ? const pw.EdgeInsets.all(16) : const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (companyLogoImage != null) ...[
                        pw.Container(
                          width: 28,
                          height: 28,
                          margin: const pw.EdgeInsets.only(right: 10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(
                              companyLogoImage,
                              width: 28,
                              height: 28,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                      pw.Text(
                        '$companyName - ALL EMPLOYEES & STAFF DIRECTORY',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'TOTAL STAFF: ${profiles.length}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _cell('#', isBold: true),
                    _cell('Employee Name', isBold: true),
                    _cell('Designation', isBold: true),
                    _cell('System Email', isBold: true),
                    _cell('Joining Date', isBold: true),
                    _cell('Basic Salary', isBold: true),
                    _cell('Status', isBold: true),
                  ],
                ),
                ...profiles.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final p = entry.value;
                  final u = userMap[p.userId];
                  final joinStr = formatNepaliDate(p.officeJoinDate, 'yyyy-MM-dd');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _cell(idx.toString()),
                      _cell(p.name, isBold: true),
                      _cell(p.designation.isNotEmpty ? p.designation : 'Staff Member'),
                      _cell(u?.email ?? 'N/A'),
                      _cell(joinStr),
                      _cell('NPR ${p.basicSalary.toStringAsFixed(0)}'),
                      _cell(u?.isActive == false ? 'INACTIVE' : 'ACTIVE'),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    );
  }

  static pw.Widget _buildInfoGrid(List<_GridItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: List.generate((items.length / 2).ceil(), (rowIndex) {
        final item1 = items[rowIndex * 2];
        final item2 = (rowIndex * 2 + 1) < items.length ? items[rowIndex * 2 + 1] : null;

        return pw.TableRow(
          children: [
            _buildGridCell(item1.label, item1.value),
            if (item2 != null)
              _buildGridCell(item2.label, item2.value)
            else
              pw.Container(),
          ],
        );
      }),
    );
  }

  static pw.Widget _buildGridCell(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.TableRow _buildTableRow(String title, String val,
      {bool isBold = false, bool isDeduction = false, bool isHeader = false}) {
    return pw.TableRow(
      decoration: isHeader ? const pw.BoxDecoration(color: PdfColors.blue100) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: isHeader ? 10 : 9,
              fontWeight: (isBold || isHeader) ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.blue900 : PdfColors.black,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            val,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: isHeader ? 10 : 9,
              fontWeight: (isBold || isHeader) ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader
                  ? PdfColors.blue900
                  : isDeduction
                      ? PdfColors.red800
                      : PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

class _GridItem {
  final String label;
  final String value;
  _GridItem(this.label, this.value);
}
