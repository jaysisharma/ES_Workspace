import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Uploads app images (attendance selfies, employee ID documents) to
/// Firebase Storage and returns their download URLs.
///
/// Folder layout (must match storage.rules):
/// - attendance_selfies/{uid}/{fileName}   – auto-deletable via lifecycle rule
/// - employee_docs/{employeeUserId}/{fileName}
class FirebaseStorageService {
  static const selfiesFolder = 'attendance_selfies';
  static const employeeDocsFolder = 'employee_docs';

  /// Uploads an attendance selfie for the signed-in user.
  /// Returns null if the user is not signed in to Firebase or the upload fails.
  static Future<String?> uploadSelfie({
    required Uint8List bytes,
    required String attendanceId,
    required String type, // 'check_in' or 'check_out'
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value(null);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _upload(
      '$selfiesFolder/$uid/${attendanceId}_${type}_$stamp.jpg',
      bytes,
    );
  }

  /// Uploads an employee ID document photo (citizenship, NIN, PAN …).
  /// Returns null if the upload fails.
  static Future<String?> uploadEmployeeDocument({
    required Uint8List bytes,
    required String employeeUserId,
    required String fileName,
  }) {
    final owner = employeeUserId.isNotEmpty ? employeeUserId : 'unassigned';
    return _upload('$employeeDocsFolder/$owner/$fileName.jpg', bytes);
  }

  static Future<String?> _upload(String path, Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('FirebaseStorageService: upload to $path failed: $e');
      return null;
    }
  }
}
