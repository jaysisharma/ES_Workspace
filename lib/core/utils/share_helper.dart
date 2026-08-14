import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unified share helper:
/// - On Android / iOS  → native system share sheet (WhatsApp visible)
/// - On Windows / macOS → custom dialog with WhatsApp, Open File, Save As, Copy
class ShareHelper {
  /// Share a PDF file.
  static Future<void> sharePdf({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String fileName,
    String subject = '',
    String message = '',
  }) async {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    // Sanitize fileName to prevent invalid path characters (slashes, colons, spaces)
    final safeFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (e) {
      debugPrint('getTemporaryDirectory FFI error, falling back to Directory.systemTemp: $e');
      tempDir = Directory.systemTemp;
    }
    final file = File('${tempDir.path}/$safeFileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pdfBytes, flush: true);

    if (isDesktop) {
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DesktopPdfShareSheet(
          file: file,
          fileName: safeFileName,
          pdfBytes: pdfBytes,
          subject: subject,
          message: message,
        ),
      );
    } else {
      try {
        // Mobile — system share sheet shows WhatsApp natively
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject.isNotEmpty ? subject : null,
          text: message.isNotEmpty ? message : null,
        );
      } catch (e) {
        debugPrint('Share.shareXFiles platform error: $e');
        if (context.mounted) {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _DesktopPdfShareSheet(
              file: file,
              fileName: safeFileName,
              pdfBytes: pdfBytes,
              subject: subject,
              message: message,
            ),
          );
        }
      }
    }
  }

  /// Share a plain text / URL message.
  static Future<void> shareText({
    required BuildContext context,
    required String message,
    String subject = '',
  }) async {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DesktopTextShareSheet(
          message: message,
          subject: subject,
        ),
      );
    } else {
      try {
        await Share.share(message, subject: subject.isNotEmpty ? subject : null);
      } catch (e) {
        debugPrint('Share.share platform error: $e');
        if (context.mounted) {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _DesktopTextShareSheet(
              message: message,
              subject: subject,
            ),
          );
        }
      }
    }
  }
}

// ── Desktop PDF Share Sheet ───────────────────────────────────────────────────

class _DesktopPdfShareSheet extends StatelessWidget {
  final File file;
  final String fileName;
  final Uint8List pdfBytes;
  final String subject;
  final String message;

  const _DesktopPdfShareSheet({
    required this.file,
    required this.fileName,
    required this.pdfBytes,
    required this.subject,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _ShareSheetContainer(
      label: fileName,
      children: [
        _ShareTile(
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          label: 'WhatsApp',
          subtitle: 'Open WhatsApp and attach the PDF',
          onTap: () => _handleWhatsApp(context),
        ),
        _ShareTile(
          icon: Icons.folder_open_rounded,
          iconColor: Colors.blueAccent,
          label: 'Open File',
          subtitle: 'Preview with your default PDF viewer',
          onTap: () async {
            Navigator.pop(context);
            if (Platform.isMacOS) {
              try {
                final res = await Process.run('open', [file.path]);
                if (res.exitCode == 0) return;
              } catch (_) {}
            }
            await OpenFilex.open(file.path);
          },
        ),
        _ShareTile(
          icon: Icons.save_alt_rounded,
          iconColor: Colors.orangeAccent,
          label: 'Save As…',
          subtitle: 'Choose where to save the PDF',
          onTap: () => _saveAs(context),
        ),
        _ShareTile(
          icon: Icons.copy_rounded,
          iconColor: Colors.purpleAccent,
          label: 'Copy File Path',
          subtitle: file.path,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: file.path));
            if (context.mounted) {
              Navigator.pop(context);
              _snack(context, '📋 File path copied to clipboard');
            }
          },
        ),
      ],
    );
  }

  Future<void> _handleWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    // Copy file path so user can attach in WhatsApp
    await Clipboard.setData(ClipboardData(text: file.path));

    final whatsappUri = Uri.parse('whatsapp://send');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        _snack(
          context,
          '✅ WhatsApp opened!\nFile path copied — attach PDF from:\n${file.path}',
          duration: const Duration(seconds: 6),
        );
      }
    } else {
      // Fallback: WhatsApp Web
      final webUri = Uri.parse('https://web.whatsapp.com');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        _snack(
          context,
          '🌐 WhatsApp Web opened!\nFile path copied — attach PDF from:\n${file.path}',
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  Future<void> _saveAs(BuildContext context) async {
    Navigator.pop(context);
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (outputPath != null) {
      final outFile = File(outputPath);
      await outFile.writeAsBytes(pdfBytes);
      if (context.mounted) _snack(context, '✅ Saved to $outputPath');
    }
  }

  void _snack(BuildContext context, String msg,
      {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: duration),
    );
  }
}

// ── Desktop Text Share Sheet ──────────────────────────────────────────────────

class _DesktopTextShareSheet extends StatelessWidget {
  final String message;
  final String subject;

  const _DesktopTextShareSheet({
    required this.message,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');
    final whatsappWebUri = Uri.parse('https://wa.me/?text=$encoded');

    return _ShareSheetContainer(
      label: subject.isNotEmpty ? subject : 'Share Message',
      children: [
        _ShareTile(
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          label: 'WhatsApp',
          subtitle: 'Send message directly via WhatsApp Desktop',
          onTap: () async {
            Navigator.pop(context);
            if (await canLaunchUrl(whatsappUri)) {
              await launchUrl(whatsappUri,
                  mode: LaunchMode.externalApplication);
            } else {
              await launchUrl(whatsappWebUri,
                  mode: LaunchMode.externalApplication);
            }
          },
        ),
        _ShareTile(
          icon: Icons.open_in_browser_rounded,
          iconColor: const Color(0xFF25D366),
          label: 'WhatsApp Web',
          subtitle: 'Open wa.me link in browser with message pre-filled',
          onTap: () async {
            Navigator.pop(context);
            await launchUrl(whatsappWebUri,
                mode: LaunchMode.externalApplication);
          },
        ),
        _ShareTile(
          icon: Icons.copy_rounded,
          iconColor: Colors.purpleAccent,
          label: 'Copy to Clipboard',
          subtitle: 'Copy full message text',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: message));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('📋 Message copied to clipboard')),
              );
            }
          },
        ),
      ],
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────

class _ShareSheetContainer extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _ShareSheetContainer(
      {required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share_rounded,
                      color: cs.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon:
                      Icon(Icons.close_rounded, color: cs.onSurface, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.3)),
          ...children,
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
            fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.35)),
      onTap: onTap,
    );
  }
}
