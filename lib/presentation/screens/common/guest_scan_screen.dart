import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'guest_pass_view_screen.dart';

class GuestScanScreen extends StatefulWidget {
  const GuestScanScreen({super.key});

  @override
  State<GuestScanScreen> createState() => _GuestScanScreenState();
}

class _GuestScanScreenState extends State<GuestScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    
    // Start camera feed on initialize
    _controller.start();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isNavigating) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isNavigating = true;
    });

    HapticFeedback.mediumImpact();
    await _controller.stop(); // Suspend camera to save power and prevent duplicate loops

    try {
      String passId = '';
      String signature = '';

      if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
        final uri = Uri.parse(rawValue);
        passId = uri.queryParameters['id'] ?? '';
        signature = uri.queryParameters['sig'] ?? '';
      } else {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map<String, dynamic>) {
          passId = decoded['id'] ?? '';
          signature = decoded['sig'] ?? '';
        }
      }

      if (!mounted) return;

      if (passId.isEmpty || signature.isEmpty) {
        _showErrorDialog('Invalid ticket QR format. Please scan an official Bhojan OS event pass.');
        return;
      }

      // Navigate to read-only guest details screen
      await context.pushPage(GuestPassViewScreen(
          passId: passId,
          signature: signature));

      // Resume camera on return
      setState(() {
        _isNavigating = false;
      });
      _controller.start();
    } catch (_) {
      _showErrorDialog('Failed to decode or read the pass QR code.');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Invalid Code',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isNavigating = false;
              });
              _controller.start();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanAreaSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Positioned(
                        top: _animation.value * (scanAreaSize - 4),
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Scan Pass (Guest View)',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Align QR to verify your ticket status',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _controller.toggleTorch(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, child) {
                        final isTorchOn = state.torchState == TorchState.on;
                        return Icon(
                          isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: isTorchOn ? Colors.yellow : Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: () => _controller.switchCamera(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
