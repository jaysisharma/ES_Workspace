import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/core/utils/share_helper.dart';

/// Raw bytes of an uploaded document plus its detected file type.
class DocumentFile {
  final Uint8List bytes;
  final String extension;
  final String mimeType;

  const DocumentFile(this.bytes, this.extension, this.mimeType);
}

/// Downloads / shares employee document photos (citizenship, NIN, PAN …).
///
/// Documents are stored either as `data:image/...;base64,` strings,
/// http(s) URLs, or local file paths — all three are supported.
class DocumentFileHelper {
  /// Loads the document's bytes, or returns null if it cannot be read.
  static Future<DocumentFile?> load(String source) async {
    try {
      Uint8List bytes;
      String? mime;
      if (source.startsWith('data:')) {
        final header = source.substring(5, source.indexOf(','));
        mime = header.split(';').first;
        bytes = base64Decode(source.split(',').last);
      } else if (source.startsWith('http://') ||
          source.startsWith('https://')) {
        final res = await http.get(Uri.parse(source));
        if (res.statusCode != 200) return null;
        bytes = res.bodyBytes;
        mime = res.headers['content-type']?.split(';').first;
      } else {
        final file = File(source);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
      }
      mime = _detectMime(bytes) ?? mime ?? 'image/jpeg';
      return DocumentFile(bytes, _extensionFor(mime), mime);
    } catch (e) {
      debugPrint('DocumentFileHelper.load failed: $e');
      return null;
    }
  }

  /// Lets the user pick where to save the document.
  static Future<void> download(
    BuildContext context, {
    required String source,
    required String baseName,
  }) async {
    final doc = await load(source);
    if (!context.mounted) return;
    if (doc == null) return _snack(context, 'Could not load document.');

    final fileName = '${_safeName(baseName)}.${doc.extension}';
    try {
      // On Android/iOS file_picker writes the bytes itself; on desktop it only
      // returns the chosen path.
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $baseName',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [doc.extension],
        bytes: doc.bytes,
      );
      if (path == null) return;
      final isDesktop = !kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      if (isDesktop) await File(path).writeAsBytes(doc.bytes, flush: true);
      if (context.mounted) _snack(context, '✅ Saved $fileName');
    } catch (e) {
      if (context.mounted) _snack(context, 'Failed to save document: $e');
    }
  }

  /// Opens the system share sheet (or the desktop share options) for the document.
  static Future<void> share(
    BuildContext context, {
    required String source,
    required String baseName,
  }) async {
    final doc = await load(source);
    if (!context.mounted) return;
    if (doc == null) return _snack(context, 'Could not load document.');

    await ShareHelper.shareFile(
      context: context,
      bytes: doc.bytes,
      fileName: '${_safeName(baseName)}.${doc.extension}',
      mimeType: doc.mimeType,
      subject: baseName,
      category: ExportCategory.employees,
    );
  }

  static String? _detectMime(Uint8List b) {
    if (b.length >= 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
      return 'application/pdf';
    }
    if (b.length >= 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  static String _extensionFor(String mime) {
    switch (mime) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  static String _safeName(String name) =>
      name.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
