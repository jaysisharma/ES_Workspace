import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/event_pass_entity.dart';
import '../../../core/services/event_pass_pdf_service.dart';
import '../../providers/event_pass_provider.dart';

class EventPassDetailsScreen extends ConsumerStatefulWidget {
  final EventPassEntity pass;

  const EventPassDetailsScreen({super.key, required this.pass});

  @override
  ConsumerState<EventPassDetailsScreen> createState() =>
      _EventPassDetailsScreenState();
}

class _EventDetailsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _EventDetailsInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventPassDetailsScreenState
    extends ConsumerState<EventPassDetailsScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event Pass'),
        content: const Text(
          'Are you sure you want to delete this event pass? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isSaving = true;
      });
      final success = await ref
          .read(eventPassNotifierProvider.notifier)
          .deletePass(widget.pass.id);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event pass deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          final errorMessage =
              ref.read(eventPassNotifierProvider).errorMessage ??
              'Failed to delete';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveOrShareQr() async {
    setState(() {
      _isSaving = true;
    });

    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/qr_pass_${widget.pass.clientName.replaceAll(' ', '_')}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'QR Pass for ${widget.pass.clientName}',
        sharePositionOrigin: rect,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share/download QR Code: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Generate secure QR payload
    final qrPayload =
        'https://bhojan-os.com/event-pass?id=${widget.pass.id}&sig=${widget.pass.passSignature}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pass Details',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete Pass',
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () =>
                EventPassPdfService.generateAndPrintPassPdf(widget.pass),
            tooltip: 'Print Pass PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('event_passes')
                .doc(widget.pass.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              EventPassEntity activePass = widget.pass;
              if (snapshot.hasData && snapshot.data!.exists) {
                activePass = EventPassEntity.fromMap(
                  snapshot.data!.data() as Map<String, dynamic>,
                );
              }

              final redeemedCount = activePass.services
                  .where((s) => s.isRedeemed)
                  .length;
              final totalCount = activePass.services.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildClientCard(activePass, colorScheme),
                    const SizedBox(height: 24),
                    _buildQrCard(qrPayload, colorScheme),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Authorized Services',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$redeemedCount / $totalCount Redeemed',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildServicesList(activePass.services, colorScheme),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientCard(EventPassEntity pass, ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (pass.photoBase64 != null &&
                    pass.photoBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.memory(
                      base64Decode(pass.photoBase64!),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pass.clientName,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        pass.clientPhone,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (pass.companyName != null && pass.companyName!.isNotEmpty) ...[
              _EventDetailsInfoRow(
                icon: Icons.business,
                label: 'CompanyName',
                value: pass.companyName!,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
            ],
            _EventDetailsInfoRow(
              icon: Icons.event_note,
              label: 'Event',
              value: pass.eventName,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 10),
            _EventDetailsInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Issued On',
              value: DateFormat('yyyy-MM-dd HH:mm').format(pass.createdAt),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(String data, ColorScheme colorScheme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text(
                        'Could not generate QR code',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unique Pass QR Code',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Redeemable only inside this application',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveOrShareQr,
              icon: const Icon(
                Icons.share_outlined,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Download / Share QR',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesList(
    List<PassServiceItem> services,
    ColorScheme colorScheme,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: service.isRedeemed
              ? Colors.green.withValues(alpha: 0.05)
              : colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      service.isRedeemed
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: service.isRedeemed
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      service.name,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: service.isRedeemed
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                        decoration: service.isRedeemed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
                if (service.isRedeemed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Redeemed',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      if (service.redeemedAt != null)
                        Text(
                          DateFormat(
                            'h:mm a, d MMM',
                          ).format(service.redeemedAt!),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Colors.green[700],
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    'Available',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
