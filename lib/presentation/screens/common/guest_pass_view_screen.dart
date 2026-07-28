import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/event_pass_entity.dart';
import '../../providers/event_pass_provider.dart';
import '../../providers/auth_provider.dart';
import 'scan_pass_screen.dart';

class GuestPassViewScreen extends ConsumerStatefulWidget {
  final String passId;
  final String signature;

  const GuestPassViewScreen({
    super.key,
    required this.passId,
    required this.signature,
  });

  @override
  ConsumerState<GuestPassViewScreen> createState() => _GuestPassViewScreenState();
}

class _GuestPassViewScreenState extends ConsumerState<GuestPassViewScreen> {
  bool _isValidating = true;
  String? _errorMessage;
  EventPassEntity? _pass;

  @override
  void initState() {
    super.initState();
    Future.microtask(_validateAndLoad);
  }

  Future<void> _validateAndLoad() async {
    final syncState = ref.read(syncProvider);
    
    // 1. Verify cryptographic signature offline immediately
    if (!EventPassEntity.verifySignature(widget.passId, widget.signature, syncState.salt)) {
      setState(() {
        _isValidating = false;
        _errorMessage = 'Cryptographic verification failed. This QR code signature is invalid or has been altered.';
      });
      return;
    }

    // 2. Fetch pass information from database (Online or LAN)
    try {
      final repo = ref.read(eventPassRepositoryProvider);
      final pass = await repo.getPassById(widget.passId);
      if (pass == null) {
        setState(() {
          _isValidating = false;
          _errorMessage = 'Ticket pass not found in the event database.';
        });
      } else {
        setState(() {
          _isValidating = false;
          _pass = pass;
        });
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
        _errorMessage = 'Failed to load ticket pass: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(authNotifierProvider).user;
    final bool isStaff = currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Pass Status',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isValidating
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView(colorScheme)
              : _buildPassView(colorScheme, isStaff),
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 54, color: Colors.red[700]),
                const SizedBox(height: 16),
                Text(
                  'Invalid Ticket Pass',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isValidating = true;
                      _errorMessage = null;
                    });
                    _validateAndLoad();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassView(ColorScheme colorScheme, bool isStaff) {
    final pass = _pass!;
    final redeemedCount = pass.services.where((s) => s.isRedeemed).length;
    final totalCount = pass.services.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Alert Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.05),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verification Mode: Only official check-in scanners can redeem your ticket.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pass Details Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass.clientName,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phone: ${pass.clientPhone}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildDetailRow('Event Name', pass.eventName),
                  const SizedBox(height: 8),
                  _buildDetailRow('Created Date', DateFormat('MMM d, yyyy').format(pass.createdAt)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Redemptions', '$redeemedCount / $totalCount Completed'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Service Redemptions List
          Text(
            'Authorized Services',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pass.services.length,
            itemBuilder: (context, index) {
              final service = pass.services[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: service.isRedeemed ? Colors.green.withValues(alpha: 0.05) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: service.isRedeemed ? Colors.green[200]! : Colors.grey[200]!,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    service.isRedeemed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: service.isRedeemed ? Colors.green[700] : Colors.grey[400],
                  ),
                  title: Text(
                    service.name,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: service.isRedeemed ? TextDecoration.lineThrough : null,
                      color: service.isRedeemed ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                  subtitle: service.isRedeemed && service.redeemedAt != null
                      ? Text(
                          'Checked In at ${DateFormat('h:mm a, d MMM').format(service.redeemedAt!)}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: Colors.green[800],
                          ),
                        )
                      : Text(
                          'Available to scan',
                          style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[500]),
                        ),
                ),
              );
            },
          ),
          
          if (isStaff) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pushReplacementPage(const ScanPassScreen());
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: Text(
                  'Open Official Scanner',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
