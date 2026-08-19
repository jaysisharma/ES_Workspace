import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import 'package:order_app/domain/entities/auth_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/repositories/auth_repository.dart';
import '../models/auth_model.dart';
import 'package:order_app/core/errors/failures.dart'; // Ensure error handling matches

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<AuthEntity?> login(String email, String password) async {
    debugPrint('🔐 [AuthRepo] Starting login for: $email');
    AuthModel? authResult;
    try {
      debugPrint(
        '🔐 [AuthRepo] Calling Firebase signInWithEmailAndPassword...',
      );
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      debugPrint(
        '🔐 [AuthRepo] Firebase Auth success! UID: ${user?.uid}, Email: ${user?.email}',
      );

      if (user == null) {
        debugPrint(
          '❌ [AuthRepo] user object is null after signInWithEmailAndPassword!',
        );
        throw ServerException(
          'Login failed: User is null after authentication.',
        );
      }

      // Fetch user role from 'users' collection
      debugPrint('🔐 [AuthRepo] Fetching Firestore doc users/${user.uid}...');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      UserRole role = UserRole.staff; // Default

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        debugPrint('🔐 [AuthRepo] Firestore doc data retrieved: $data');
        if (data.containsKey('role')) {
          role = _parseRole(data['role'] as String?);
        }
        debugPrint('🔐 [AuthRepo] Parsed user role: $role');
      } else {
        debugPrint(
          '⚠️ [AuthRepo] Firestore document users/${user.uid} NOT FOUND! Checking by email...',
        );
        final emailQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: (user.email ?? email).trim())
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          final docData = emailQuery.docs.first.data();
          role = _parseRole(docData['role'] as String?);
          await _firestore.collection('users').doc(user.uid).set({
            ...docData,
            'id': user.uid,
          }, SetOptions(merge: true));
          debugPrint('✅ [AuthRepo] Recovered & linked Firestore profile to UID: ${user.uid}');
        } else {
          final targetEmail = user.email ?? email;
          final defaultRole = targetEmail.toLowerCase().contains('finance')
              ? UserRole.finance
              : targetEmail.toLowerCase().contains('admin')
                  ? UserRole.admin
                  : UserRole.staff;
          role = defaultRole;
          await _firestore.collection('users').doc(user.uid).set({
            'id': user.uid,
            'email': targetEmail.trim(),
            'name': targetEmail.split('@').first,
            'role': defaultRole.name,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ [AuthRepo] Auto-provisioned missing Firestore user doc for UID: ${user.uid} with role: $role');
        }
      }

      authResult = AuthModel(
        uid: user.uid,
        email: user.email ?? email,
        role: role,
      );
    } on FirebaseAuthException catch (e, stack) {
      debugPrint(
        '❌ [AuthRepo] FirebaseAuthException [${e.code}]: ${e.message}',
      );
      if (e.code == 'keychain-error') {
        debugPrint(
          '⚠️ [AuthRepo] Keychain error encountered! Attempting Firebase REST API login fallback...',
        );
        authResult = await _loginViaRestApi(email, password) as AuthModel?;
      } else {
        debugPrint('❌ [AuthRepo] StackTrace: $stack');
        throw ServerException('FirebaseAuth Error (${e.code}): ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ [AuthRepo] Generic exception during login: $e');
      debugPrint('❌ [AuthRepo] StackTrace: $stack');
      throw ServerException('Login failed: ${e.toString()}');
    }

    if (authResult != null) {
      await _saveSessionToLocal(authResult);
    }

    return authResult;
  }

  /// Save active user session locally to SharedPreferences.
  /// Admin sessions are NEVER persisted — admins auto-logout when the app closes.
  Future<void> _saveSessionToLocal(AuthEntity auth) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (auth.role == UserRole.admin) {
        // Admin: wipe any old session so they are never auto-resumed
        await prefs.remove('user_session_v1');
        debugPrint(
          '🔒 [AuthRepo] Admin session NOT persisted (auto-logout on app close)',
        );
        return;
      }
      await prefs.setString(
        'user_session_v1',
        jsonEncode({
          'uid': auth.uid,
          'email': auth.email,
          'role': auth.role.name,
        }),
      );
      debugPrint(
        '💾 [AuthRepo] Persistent session saved to local storage for ${auth.email} (${auth.role.name})',
      );
    } catch (e) {
      debugPrint('⚠️ [AuthRepo] Error saving local session: $e');
    }
  }

  /// REST API fallback for macOS desktop when native OS Keychain storage fails
  Future<AuthEntity?> _loginViaRestApi(String email, String password) async {
    try {
      final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
      final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
      );

      debugPrint(
        '🌐 [AuthRepo REST API] Requesting Firebase Identity Toolkit API...',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final uid = data['localId'] as String;
        final userEmail = data['email'] as String? ?? email;
        debugPrint('✅ [AuthRepo REST API] REST Login successful! UID: $uid');

        debugPrint(
          '🔐 [AuthRepo REST API] Fetching Firestore doc users/$uid...',
        );
        final userDoc = await _firestore.collection('users').doc(uid).get();
        UserRole role = UserRole.staff;
        if (userDoc.exists && userDoc.data() != null) {
          final docData = userDoc.data()!;
          debugPrint(
            '🔐 [AuthRepo REST API] Firestore doc retrieved: $docData',
          );
          if (docData.containsKey('role')) {
            role = _parseRole(docData['role'] as String?);
          }
          debugPrint('🔐 [AuthRepo REST API] Parsed role: $role');
        } else {
          debugPrint(
            '⚠️ [AuthRepo REST API] Firestore document users/$uid NOT FOUND! Checking by email...',
          );
          final emailQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: userEmail.trim())
              .limit(1)
              .get();

          if (emailQuery.docs.isNotEmpty) {
            final docData = emailQuery.docs.first.data();
            role = _parseRole(docData['role'] as String?);
            await _firestore.collection('users').doc(uid).set({
              ...docData,
              'id': uid,
            }, SetOptions(merge: true));
            debugPrint('✅ [AuthRepo REST API] Recovered & linked Firestore profile to UID: $uid');
          } else {
            final defaultRole = userEmail.toLowerCase().contains('finance')
                ? UserRole.finance
                : userEmail.toLowerCase().contains('admin')
                    ? UserRole.admin
                    : UserRole.staff;
            role = defaultRole;
            await _firestore.collection('users').doc(uid).set({
              'id': uid,
              'email': userEmail.trim(),
              'name': userEmail.split('@').first,
              'role': defaultRole.name,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ [AuthRepo REST API] Auto-provisioned missing Firestore user doc for UID: $uid with role: $role');
          }
        }

        return AuthModel(uid: uid, email: userEmail, role: role);
      } else {
        final errorObj = data['error'] as Map<String, dynamic>?;
        final message = errorObj?['message'] as String? ?? 'LOGIN_FAILED';
        debugPrint('❌ [AuthRepo REST API] REST Login failed: $message');

        if (message.contains('INVALID_PASSWORD') ||
            message.contains('EMAIL_NOT_FOUND') ||
            message.contains('INVALID_LOGIN_CREDENTIALS')) {
          throw ServerException(
            'FirebaseAuth Error (invalid-credential): Incorrect email or password.',
          );
        }
        throw ServerException('FirebaseAuth Error (rest-api-error): $message');
      }
    } catch (e, stack) {
      if (e is ServerException) rethrow;
      debugPrint('❌ [AuthRepo REST API] Exception during REST login: $e');
      debugPrint('❌ [AuthRepo REST API] StackTrace: $stack');
      throw ServerException('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<AuthEntity?> register(
    String email,
    String password,
    UserRole role,
  ) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw ServerException(
          'Registration failed: User is null after creation.',
        );
      }

      final roleString = role.toString().split('.').last.toLowerCase();

      // Store complete user data in 'users' collection
      await _firestore.collection('users').doc(user.uid).set({
        'id': user.uid,
        'email': user.email ?? email,
        'name': (user.email ?? email).split('@').first,
        'role': roleString,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final auth = AuthModel(
        uid: user.uid,
        email: user.email ?? email,
        role: role,
      );
      await _saveSessionToLocal(auth);
      return auth;
    } on FirebaseAuthException catch (e) {
      throw ServerException('FirebaseAuth Error (${e.code}): ${e.message}');
    } catch (e) {
      throw ServerException('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session_v1');
      debugPrint('🧹 [AuthRepo] Local persistent session cleared upon logout');
    } catch (e) {
      throw ServerException('Logout failed: ${e.toString()}');
    }
  }

  @override
  Future<AuthEntity?> getCurrentUser() async {
    try {
      String? uid;
      String? email;
      UserRole? role;

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        uid = firebaseUser.uid;
        email = firebaseUser.email;
        debugPrint('🔐 [AuthRepo] Firebase currentUser active: $uid');
      } else {
        debugPrint(
          '🔍 [AuthRepo] Firebase currentUser is null, checking local SharedPreferences persistence...',
        );
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('user_session_v1');
        if (savedJson != null) {
          final data = jsonDecode(savedJson) as Map<String, dynamic>;
          uid = data['uid'] as String?;
          email = data['email'] as String?;
          if (data['role'] != null) {
            role = _parseRole(data['role'] as String?);
          }

          // Admin sessions should never be restored from local storage.
          // If somehow an admin session slipped in, discard it.
          if (role == UserRole.admin) {
            debugPrint(
              '🔒 [AuthRepo] Discarding stale admin local session — admin must re-login.',
            );
            await prefs.remove('user_session_v1');
            return null;
          }

          debugPrint(
            '💾 [AuthRepo] Found saved local session! UID: $uid, Email: $email, Role: $role',
          );
        }
      }

      if (uid == null) {
        debugPrint(
          'ℹ️ [AuthRepo] No active session found locally or in Firebase.',
        );
        return null;
      }

      // Try fetching/updating latest user profile from Firestore if online
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          if (data.containsKey('role')) {
            role = _parseRole(data['role'] as String?);
          }
        }
      } catch (e) {
        debugPrint(
          '⚠️ [AuthRepo] Could not refresh Firestore user profile online: $e. Using local session info.',
        );
      }

      role ??= UserRole.staff;

      // Admin: sign out of Firebase Auth immediately so the next cold start
      // will NOT find a cached Firebase token. This enforces the auto-logout.
      if (role == UserRole.admin && firebaseUser != null) {
        try {
          await _firebaseAuth.signOut();
          debugPrint(
            '🔒 [AuthRepo] Admin Firebase token cleared — will require login on next app start.',
          );
        } catch (_) {}
        // Still return the admin entity for THIS session so the app works now.
      }

      final auth = AuthModel(uid: uid, email: email ?? '', role: role);
      // _saveSessionToLocal is a no-op for admin (won't persist)
      await _saveSessionToLocal(auth);
      return auth;
    } catch (e) {
      debugPrint('⚠️ [AuthRepo] Failed to get current user session: $e');
      return null;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw ServerException('Failed to update password: No user logged in.');
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw ServerException('FirebaseAuth Error: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to update password: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final uid = user.uid;
        try {
          await _firestore.collection('users').doc(uid).update({
            'isActive': false,
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('⚠️ [AuthRepo] Firestore user doc update on delete: $e');
        }

        await user.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session_v1');
      debugPrint('🧹 [AuthRepo] User account and local session deleted');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw ServerException(
          'Security Check: Please log out and log back in before deleting your account.',
        );
      }
      throw ServerException('FirebaseAuth Error (${e.code}): ${e.message}');
    } catch (e) {
      throw ServerException('Account deletion failed: ${e.toString()}');
    }
  }

  UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.staff;
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'finance':
        return UserRole.finance;
      case 'staff':
        return UserRole.staff;
      case 'founder':
      case 'director':
      case 'ceo':
        return UserRole.founder;
      default:
        return UserRole.staff;
    }
  }
}
