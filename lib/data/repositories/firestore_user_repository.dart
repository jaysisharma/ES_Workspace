import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/repositories/user_repository.dart';
import '../models/user_model.dart';
import 'package:order_app/core/errors/failures.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addUser(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .set(userModel.toJson());
    } catch (e) {
      throw ServerException('Failed to add user: ${e.toString()}');
    }
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      throw ServerException('Failed to get all users: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      // NOTE: This typically relies on FirebaseAuth to get the current user's ID.
      // Since FirebaseAuth isn't passed here to keep responsibilities separate,
      // it is usually fetched via a use case or another provider before calling this.
      // Therefore, this method in FirestoreUserRepository could be implemented to
      // fetch a user by ID instead, or throw unimplemented for now if FirebaseAuth
      // isn't accessible here. To comply strictly with the interface signature:

      throw UnimplementedError(
        'getCurrentUser requires an ID or FirebaseAuth context. Use getUserById instead.',
      );
    } catch (e) {
      throw ServerException('Failed to get current user: ${e.toString()}');
    }
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .update(userModel.toJson());
    } catch (e) {
      throw ServerException('Failed to update user: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw ServerException('Failed to delete user: ${e.toString()}');
    }
  }
}
