import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:order_app/presentation/providers/event_pass_provider.dart';

class SyncSetupDialog extends ConsumerStatefulWidget {
  const SyncSetupDialog({super.key});

  @override
  ConsumerState<SyncSetupDialog> createState() => _SyncSetupDialogState();
}

class _SyncSetupDialogState extends ConsumerState<SyncSetupDialog> {
  final TextEditingController _ipController = TextEditingController();
  bool _isScanning = false;
  final MobileScannerController _scannerController = MobileScannerController(autoStart: false);

  @override
  void dispose() {
    _ipController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (syncState.isReconciling) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Uploading offline database to Cloud...',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: _isScanning ? _buildScannerView() : _buildMainView(syncState, colorScheme),
    );
  }

  Widget _buildMainView(SyncState syncState, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Connection Setup',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select how this scanner connects to the database.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            if (syncState.mode != PassSyncMode.localClient && syncState.hostIp.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  ref.read(syncProvider.notifier).setClientMode(syncState.hostIp);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_find, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Found local LAN Host at ${syncState.hostIp}. Tap to connect automatically!',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildModeTile(
              title: 'Cloud Mode (Internet)',
              subtitle: 'Synchronizes database in real-time via online Google Firestore.',
              icon: Icons.cloud_outlined,
              selected: syncState.mode == PassSyncMode.cloud,
              colorScheme: colorScheme,
              onTap: () {
                ref.read(syncProvider.notifier).setCloudMode();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _buildModeTile(
              title: 'Host Local Network (LAN)',
              subtitle: 'Acts as the central database host over local Wi-Fi. (Offline)',
              icon: Icons.router_outlined,
              selected: syncState.mode == PassSyncMode.localHost,
              colorScheme: colorScheme,
              onTap: () {
                ref.read(syncProvider.notifier).setHostMode();
              },
            ),
            const SizedBox(height: 12),
            _buildModeTile(
              title: 'Join Local Network (Client)',
              subtitle: 'Connects to a Host device IP to sync scanner check-ins. (Offline)',
              icon: Icons.settings_input_antenna_outlined,
              selected: syncState.mode == PassSyncMode.localClient,
              colorScheme: colorScheme,
              onTap: () {
                if (syncState.hostIp.isNotEmpty) {
                  _ipController.text = syncState.hostIp;
                }
                ref.read(syncProvider.notifier).setClientMode(syncState.hostIp);
              },
            ),
            if (syncState.mode == PassSyncMode.localHost) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Host IP address: ${syncState.hostIp}',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: jsonEncode({'hostIp': syncState.hostIp}),
                        version: QrVersions.auto,
                        size: 140.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Other devices scan this to connect',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (syncState.mode == PassSyncMode.localClient || 
                _ipController.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        hintText: 'Enter Host IP (e.g. 192.168.1.5)',
                        labelText: 'Host IP Address',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _startScanner,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    final ip = _ipController.text.trim();
                    if (ip.isNotEmpty) {
                      ref.read(syncProvider.notifier).setClientMode(ip);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Connect Client',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? colorScheme.primary : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _startScanner() {
    _scannerController.start();
    setState(() {
      _isScanning = true;
    });
  }

  Widget _buildScannerView() {
    return Container(
      width: double.infinity,
      height: 350,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  try {
                    final data = jsonDecode(barcode.rawValue!);
                    final ip = data['hostIp'];
                    if (ip != null) {
                      _scannerController.stop();
                      setState(() {
                        _ipController.text = ip;
                        _isScanning = false;
                      });
                      break;
                    }
                  } catch (_) {
                    // Not a valid IP json, ignore
                  }
                }
              }
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'sync_setup_dialog_fab',
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              onPressed: () {
                _scannerController.stop();
                setState(() {
                  _isScanning = false;
                });
              },
              child: const Icon(Icons.close),
            ),
          ),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
