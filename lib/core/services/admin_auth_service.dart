import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/firebase_options.dart';

class AdminAuthService {
  AdminAuthService._();

  /// Creates a new user account in Firebase Auth using the REST API (to completely bypass
  /// macOS Keychain issues and prevent signing out the active Admin session) and creates
  /// their user document in Firestore `users/$uid`.
  static Future<UserEntity> createEmployeeUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? phone,
    bool isActive = true,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    String finalUid = const Uuid().v4();
    bool authCreated = false;

    try {
      // 1. Attempt REST API SignUp (Identity Toolkit)
      final signUpUrl = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
      );

      final signUpResponse = await http.post(
        signUpUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': trimmedEmail,
          'password': trimmedPassword,
          'returnSecureToken': true,
        }),
      );

      final signUpData = jsonDecode(signUpResponse.body) as Map<String, dynamic>;

      if (signUpResponse.statusCode == 200 && signUpData['localId'] != null) {
        finalUid = signUpData['localId'] as String;
        authCreated = true;
        debugPrint('✅ [AdminAuthService] REST Auth account created with UID: $finalUid');
      } else {
        final errorMsg = (signUpData['error'] as Map<String, dynamic>?)?['message'] as String? ?? '';
        debugPrint('⚠️ [AdminAuthService] REST SignUp message: $errorMsg');

        if (errorMsg.contains('EMAIL_EXISTS')) {
          // If the email already exists in Firebase Auth, sign in via REST to retrieve the real UID
          final signInUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
          );
          final signInResponse = await http.post(
            signInUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': trimmedEmail,
              'password': trimmedPassword,
              'returnSecureToken': true,
            }),
          );

          final signInData = jsonDecode(signInResponse.body) as Map<String, dynamic>;
          if (signInResponse.statusCode == 200 && signInData['localId'] != null) {
            finalUid = signInData['localId'] as String;
            authCreated = true;
            debugPrint('✅ [AdminAuthService] Existing Auth account retrieved with UID: $finalUid');
          } else {
            // Check if there is an existing Firestore record by email
            final existingDocs = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: trimmedEmail)
                .limit(1)
                .get();

            if (existingDocs.docs.isNotEmpty) {
              finalUid = existingDocs.docs.first.id;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AdminAuthService] Error during REST auth creation: $e');
    }

    // 2. Write or Update the User Document in Firestore `users/$finalUid`
    final userDoc = {
      'id': finalUid,
      'name': name.trim().isNotEmpty ? name.trim() : trimmedEmail.split('@').first,
      'email': trimmedEmail,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'role': role.name,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'authCreated': authCreated,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(finalUid)
        .set(userDoc, SetOptions(merge: true));

    debugPrint('✅ [AdminAuthService] Firestore users/$finalUid updated successfully.');

    return UserEntity(
      id: finalUid,
      name: userDoc['name'] as String,
      email: trimmedEmail,
      role: role,
      isActive: isActive,
    );
  }
}
