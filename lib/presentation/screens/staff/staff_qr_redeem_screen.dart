import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:order_app/presentation/providers/event_pass_provider.dart';
import 'package:order_app/presentation/widgets/common/sync_setup_dialog.dart';
import 'package:order_app/presentation/screens/common/passes/event_pass_details_screen.dart';
import 'package:order_app/presentation/screens/common/passes/scan_pass_screen.dart';

class StaffQrRedeemScreen extends ConsumerWidget {
  const StaffQrRedeemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncProvider);
    final passState = ref.watch(eventPassNotifierProvider);

    // Filter passes that have at least one service redeemed
    final recentlyRedeemed = passState.passes.where((pass) {
      return pass.services.any((s) => s.isRedeemed);
    }).toList();

    // Sort by latest redeemed timestamp
    recentlyRedeemed.sort((a, b) {
      final aLatest = a.services
          .where((s) => s.isRedeemed && s.redeemedAt != null)
          .map((s) => s.redeemedAt!)
          .fold<DateTime>(DateTime(2000), (prev, curr) => curr.isAfter(prev) ? curr : prev);
      final bLatest = b.services
          .where((s) => s.isRedeemed && s.redeemedAt != null)
          .map((s) => s.redeemedAt!)
          .fold<DateTime>(DateTime(2000), (prev, curr) => curr.isAfter(prev) ? curr : prev);
      return bLatest.compareTo(aLatest);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'QR Pass Redemption',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Connection status chip
          _buildConnectionChip(context, syncState),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(eventPassNotifierProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large scanner CTA Card
              _buildScannerCard(context, colorScheme),
              const SizedBox(height: 32),
              Text(
                'Recent Redemptions',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (recentlyRedeemed.isEmpty)
                _buildEmptyState(colorScheme)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentlyRedeemed.length > 5 ? 5 : recentlyRedeemed.length,
                  itemBuilder: (context, index) {
                    final pass = recentlyRedeemed[index];
                    // Get latest redeemed service
                    final latestService = pass.services
                        .where((s) => s.isRedeemed)
                        .reduce((curr, next) {
                          if (curr.redeemedAt == null) return next;
                          if (next.redeemedAt == null) return curr;
                          return next.redeemedAt!.isAfter(curr.redeemedAt!) ? next : curr;
                        });

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[50],
                          child: Icon(Icons.check_circle_outline, color: Colors.green[700]),
                        ),
                        title: Text(
                          pass.clientName,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Redeemed: ${latestService.name}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // Navigate to details if they want to review all services of this client
                          context.pushPage(EventPassDetailsScreen(pass: pass));
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionChip(BuildContext context, SyncState syncState) {
    String label = 'Cloud';
    IconData icon = Icons.cloud_done_outlined;
    Color color = Colors.green;

    if (syncState.mode == PassSyncMode.localHost) {
      label = 'Host';
      icon = Icons.router_outlined;
      color = Colors.blue;
    } else if (syncState.mode == PassSyncMode.localClient) {
      label = 'LAN';
      icon = Icons.settings_input_antenna_outlined;
      color = Colors.orange;
    }

    return TextButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const SyncSetupDialog(),
        );
      },
      icon: Icon(icon, color: color, size: 18),
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildScannerCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan Client Pass QR',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify tickets and check in guests for meals, photoshoots, or drinks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                context.pushPage(const ScanPassScreen());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Open Scanner',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No check-ins processed yet',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan passes above to start redeeming services.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }
}
