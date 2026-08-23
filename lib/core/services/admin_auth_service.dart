import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/firebase_options.dart';

class AdminAuthService {
  AdminAuthService._();

  static const _authScope = 'https://www.googleapis.com/auth/identitytoolkit';
  static const _cloudPlatformScope = 'https://www.googleapis.com/auth/cloud-platform';
  static const _projectId = 'orderapp-bcea2';

  static http.Client? _authAdminClient;

  /// Returns an authenticated Google Cloud client with Identity Toolkit & Cloud Platform scopes.
  static Future<http.Client?> _getAdminAuthClient() async {
    try {
      if (_authAdminClient != null) return _authAdminClient!;
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final credentials = ServiceAccountCredentials.fromJson(jsonDecode(jsonString));
      _authAdminClient = await clientViaServiceAccount(credentials, [
        _authScope,
        _cloudPlatformScope,
      ]);
      return _authAdminClient!;
    } catch (e) {
      debugPrint('⚠️ [AdminAuthService] Could not initialize service account client: $e');
      return null;
    }
  }

  /// Creates a new user account in Firebase Auth using Service Account Admin API / REST API
  /// and creates their user document in Firestore `users/$uid`.
  static Future<UserEntity> createEmployeeUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? phone,
    bool isActive = true,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    String finalUid = const Uuid().v4();
    bool authCreated = false;

    try {
      final client = await _getAdminAuthClient();
      if (client != null) {
        // Create user via Admin API
        final createUrl = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts',
        );
        final res = await client.post(
          createUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'localId': finalUid,
            'email': trimmedEmail,
            'password': trimmedPassword,
            'emailVerified': true,
            'displayName': name.trim(),
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['localId'] != null) {
            finalUid = data['localId'] as String;
          }
          authCreated = true;
          debugPrint('✅ [AdminAuthService] Service account created Auth account: $finalUid');
        } else {
          // If already exists, update password and get UID
          debugPrint('⚠️ [AdminAuthService] Create returned ${res.statusCode}: ${res.body}. Checking existing...');
          final lookupUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:lookup',
          );
          final lookupRes = await client.post(
            lookupUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': [trimmedEmail]}),
          );
          if (lookupRes.statusCode == 200) {
            final lookupData = jsonDecode(lookupRes.body) as Map<String, dynamic>;
            final usersList = lookupData['users'] as List<dynamic>?;
            if (usersList != null && usersList.isNotEmpty) {
              final existingLocalId = usersList.first['localId'] as String;
              finalUid = existingLocalId;
              authCreated = true;

              // Update password for existing user
              final updateUrl = Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:update',
              );
              await client.post(
                updateUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'localId': existingLocalId,
                  'password': trimmedPassword,
                  'emailVerified': true,
                }),
              );
              debugPrint('✅ [AdminAuthService] Existing Auth account ($finalUid) password updated.');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AdminAuthService] Error creating user via service account: $e');
    }

    // Fallback if service account was unavailable
    if (!authCreated) {
      try {
        final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
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
        }
      } catch (_) {}
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

  /// Updates employee email, password, and role across Firebase Auth and Firestore
  static Future<void> updateEmployeeCredentials({
    required String userId,
    required String oldEmail,
    required String newEmail,
    String? newPassword,
    required UserRole role,
    String? name,
    String? profileId,
  }) async {
    final cleanNewEmail = newEmail.trim();
    final cleanOldEmail = oldEmail.trim();
    final cleanPassword = newPassword?.trim();

    debugPrint('🔄 [AdminAuthService] Updating credentials for userId=$userId, oldEmail=$cleanOldEmail, newEmail=$cleanNewEmail, role=${role.name}');

    // 1. Update Firebase Authentication using Service Account Admin API
    String finalAuthUid = userId;
    try {
      final client = await _getAdminAuthClient();
      if (client != null) {
        String? targetLocalId;
        final lookupUrl = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:lookup',
        );

        // Try lookup by old email
        if (cleanOldEmail.isNotEmpty) {
          final res = await client.post(
            lookupUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': [cleanOldEmail]}),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final usersList = data['users'] as List<dynamic>?;
            if (usersList != null && usersList.isNotEmpty) {
              targetLocalId = usersList.first['localId'] as String?;
            }
          }
        }

        // Try lookup by new email
        if (targetLocalId == null && cleanNewEmail.isNotEmpty) {
          final res = await client.post(
            lookupUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': [cleanNewEmail]}),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final usersList = data['users'] as List<dynamic>?;
            if (usersList != null && usersList.isNotEmpty) {
              targetLocalId = usersList.first['localId'] as String?;
            }
          }
        }

        // Try lookup by userId as localId
        if (targetLocalId == null && userId.isNotEmpty) {
          final res = await client.post(
            lookupUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'localId': [userId]}),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final usersList = data['users'] as List<dynamic>?;
            if (usersList != null && usersList.isNotEmpty) {
              targetLocalId = usersList.first['localId'] as String?;
            }
          }
        }

        if (targetLocalId != null) {
          finalAuthUid = targetLocalId;
          final updateUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:update',
          );
          final updateBody = <String, dynamic>{
            'localId': targetLocalId,
            if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
            if (cleanPassword != null && cleanPassword.isNotEmpty) 'password': cleanPassword,
            if (name != null && name.trim().isNotEmpty) 'displayName': name.trim(),
            'emailVerified': true,
          };
          final updateRes = await client.post(
            updateUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(updateBody),
          );
          debugPrint('✅ [AdminAuthService] Service account updated Auth account ($targetLocalId): ${updateRes.statusCode} - ${updateRes.body}');
        } else {
          // Create account in Firebase Auth
          final createUrl = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts',
          );
          final createBody = <String, dynamic>{
            if (userId.isNotEmpty) 'localId': userId,
            'email': cleanNewEmail,
            if (cleanPassword != null && cleanPassword.isNotEmpty) 'password': cleanPassword,
            if (name != null && name.trim().isNotEmpty) 'displayName': name.trim(),
            'emailVerified': true,
          };
          final createRes = await client.post(
            createUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(createBody),
          );
          debugPrint('✅ [AdminAuthService] Service account created Auth account: ${createRes.statusCode} - ${createRes.body}');
          if (createRes.statusCode == 200) {
            final createData = jsonDecode(createRes.body) as Map<String, dynamic>;
            if (createData['localId'] != null) {
              finalAuthUid = createData['localId'] as String;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AdminAuthService] Error updating Firebase Auth via service account: $e');
    }

    // 2. Update/Merge in `users` collection by document ID
    final targetDocId = finalAuthUid.isNotEmpty ? finalAuthUid : userId;
    await FirebaseFirestore.instance.collection('users').doc(targetDocId).set({
      'id': targetDocId,
      if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update if userId was different
    if (userId.isNotEmpty && userId != targetDocId) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'id': targetDocId,
        if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Also update any user documents matching oldEmail
    if (cleanOldEmail.isNotEmpty && cleanOldEmail != cleanNewEmail) {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanOldEmail)
          .get();
      for (final doc in userQuery.docs) {
        await doc.reference.set({
          'id': targetDocId,
          if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          'role': role.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // 3. Update in `employee_profiles` collection
    if (profileId != null && profileId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('employee_profiles')
          .doc(profileId)
          .set({
        'userId': targetDocId,
        if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Update any profile where userId == userId or userId == targetDocId
    final profileQuery = await FirebaseFirestore.instance
        .collection('employee_profiles')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in profileQuery.docs) {
      await doc.reference.set({
        'userId': targetDocId,
        if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Update any profile where email == oldEmail
    if (cleanOldEmail.isNotEmpty && cleanOldEmail != cleanNewEmail) {
      final emailProfileQuery = await FirebaseFirestore.instance
          .collection('employee_profiles')
          .where('email', isEqualTo: cleanOldEmail)
          .get();
      for (final doc in emailProfileQuery.docs) {
        await doc.reference.set({
          'userId': targetDocId,
          if (cleanNewEmail.isNotEmpty) 'email': cleanNewEmail,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          'role': role.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    debugPrint('✅ [AdminAuthService] Credentials updated successfully for $cleanNewEmail (Auth UID: $targetDocId)');
  }
}
