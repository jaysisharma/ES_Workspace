import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// In-memory session cache for instant subsequent opens
final Map<String, Uint8List> _receiptMemoryCache = {};

class ReceiptViewerModal extends ConsumerStatefulWidget {
  final String title;
  final String? url;
  final String? path;
  final Uint8List? initialBytes;

  const ReceiptViewerModal({
    super.key,
    required this.title,
    this.url,
    this.path,
    this.initialBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? url,
    String? path,
    Uint8List? initialBytes,
  }) async {
    final lower = title.toLowerCase();
    if (lower.endsWith('.pdf')) {
      // If it's PDF, load bytes and open in-app PdfPreviewScreen
      Uint8List? bytes = initialBytes;
      if (bytes == null && url != null && url.isNotEmpty) {
        bytes = _receiptMemoryCache[url];
      }

      if (bytes != null && bytes.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: bytes,
              title: title,
              fileName: title,
            ),
          ),
        );
        return;
      }
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ReceiptViewerModal(
          title: title,
          url: url,
          path: path,
          initialBytes: initialBytes,
        ),
      ),
    );
  }

  @override
  ConsumerState<ReceiptViewerModal> createState() => _ReceiptViewerModalState();
}

class _ReceiptViewerModalState extends ConsumerState<ReceiptViewerModal> {
  Uint8List? _bytes;
  bool _isLoading = false;
  String? _errorMessage;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadBytes() async {
    if (widget.initialBytes != null && widget.initialBytes!.isNotEmpty) {
      _bytes = widget.initialBytes;
      if (widget.url != null) _receiptMemoryCache[widget.url!] = _bytes!;
      return;
    }

    if (widget.url != null && _receiptMemoryCache.containsKey(widget.url!)) {
      _bytes = _receiptMemoryCache[widget.url!];
      return;
    }

    final targetUrl = widget.url;
    if (targetUrl == null || targetUrl.isEmpty) {
      setState(() => _errorMessage = 'No file URL provided');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. First attempt direct HTTP get
      final uri = Uri.parse(targetUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = response.bodyBytes;
            _receiptMemoryCache[targetUrl] = _bytes!;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Fallback attempt: Authenticated Synology API download
      final synologyConfig =
          ref.read(companyDocumentNotifierProvider).synologyConfig;
      final synologyService = SynologyService();
      final sid = await synologyService.authenticate(synologyConfig);

      final filePath = widget.path ??
          '${synologyConfig.destinationFolder}/${widget.title}';
      final cleanBase = synologyConfig.host.replaceAll(RegExp(r'/+$'), '');

      final downloadUri = Uri.parse(
        '$cleanBase/webapi/entry.cgi?api=SYNO.FileStation.Download&version=2&method=download&path=${Uri.encodeComponent(filePath)}&mode=open${sid != null ? "&_sid=$sid" : ""}',
      );

      final synoRes = await http.get(downloadUri).timeout(const Duration(seconds: 15));
      if (synoRes.statusCode == 200 && synoRes.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = synoRes.bodyBytes;
            _receiptMemoryCache[targetUrl] = _bytes!;
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load receipt preview directly.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Loading failed: $e';
        });
      }
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  Future<void> _openExternal() async {
    if (widget.url == null) return;
    try {
      final uri = Uri.parse(widget.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131c26) : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 680),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF10b981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'In-App Receipt Viewer',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_bytes != null) ...[
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map_rounded, size: 20),
                    tooltip: 'Reset Zoom',
                    onPressed: _resetZoom,
                  ),
                ],
                if (widget.url != null) ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    tooltip: 'Open in Browser',
                    onPressed: _openExternal,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Main Preview Canvas
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0b1219) : const Color(0xFFf1f5f9),
              alignment: Alignment.center,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Loading receipt preview...',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      );
    }

    if (_bytes != null) {
      final isPdf = widget.title.toLowerCase().endsWith('.pdf');
      if (isPdf) {
        return PdfPreviewScreen(
          pdfData: _bytes!,
          title: widget.title,
          fileName: widget.title,
        );
      }

      return InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 4.0,
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: Image.memory(
            _bytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Could not decode image format', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Preview unavailable',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (widget.url != null) ...[
            ElevatedButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('Open with External Viewer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10b981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
