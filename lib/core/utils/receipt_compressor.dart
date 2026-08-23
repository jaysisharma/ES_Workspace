import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class ReceiptCompressor {
  /// Compresses receipt/bill images to ensure ultra-fast uploads while keeping crisp readability.
  /// If the file is a PDF or already very small, it returns the original bytes untouched.
  static Future<Uint8List> compressReceiptBytes({
    required Uint8List rawBytes,
    required String fileName,
    int maxDimension = 1400,
  }) async {
    final lowerName = fileName.toLowerCase();

    // Do not alter PDF files
    if (lowerName.endsWith('.pdf')) {
      return rawBytes;
    }

    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.heic');

    if (!isImage) {
      return rawBytes;
    }

    final originalSizeKb = rawBytes.lengthInBytes / 1024;

    try {
      // Decode the image header first to check dimensions
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;

      // If the image is already small in dimensions and file size (< 250 KB), skip
      if (width <= maxDimension &&
          height <= maxDimension &&
          rawBytes.lengthInBytes <= 250 * 1024) {
        return rawBytes;
      }

      int targetWidth;
      int targetHeight;

      if (width > height) {
        targetWidth = width > maxDimension ? maxDimension : width;
        targetHeight = (height * (targetWidth / width)).round();
      } else {
        targetHeight = height > maxDimension ? maxDimension : height;
        targetWidth = (width * (targetHeight / height)).round();
      }

      // Re-decode with target resolution (hardware-accelerated downscaling)
      final scaledCodec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );

      final scaledFrame = await scaledCodec.getNextFrame();
      final byteData = await scaledFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final compressedBytes = byteData.buffer.asUint8List();
        final compressedSizeKb = compressedBytes.lengthInBytes / 1024;
        debugPrint(
          '[ReceiptCompressor] Compressed "$fileName" from ${originalSizeKb.toStringAsFixed(1)} KB to ${compressedSizeKb.toStringAsFixed(1)} KB (Resolution: ${targetWidth}x$targetHeight)',
        );
        return compressedBytes;
      }
    } catch (e) {
      debugPrint('[ReceiptCompressor] Compression failed, falling back to original: $e');
    }

    return rawBytes;
  }

  /// Convenience helper to load and compress from picked File or bytes
  static Future<Uint8List?> getCompressedBytesFromFile({
    Uint8List? rawBytes,
    String? filePath,
    required String fileName,
  }) async {
    Uint8List? bytes = rawBytes;
    if (bytes == null && filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    }

    if (bytes == null || bytes.isEmpty) return null;

    return await compressReceiptBytes(
      rawBytes: bytes,
      fileName: fileName,
    );
  }
}
