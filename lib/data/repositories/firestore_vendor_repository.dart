import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/vendor_entity.dart';
import 'package:order_app/domain/repositories/vendor_repository.dart';
import 'package:order_app/core/errors/failures.dart';

class FirestoreVendorRepository implements VendorRepository {
  final FirebaseFirestore _firestore;

  FirestoreVendorRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<VendorEntity>> getAllVendors() async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to get vendors: ${e.toString()}');
    }
  }

  @override
  Future<void> addVendor(VendorEntity vendor) async {
    try {
      final docRef = _firestore.collection('vendors').doc();
      await docRef.set(_toJson(vendor.copyWith()).toMap(docRef.id));
    } catch (e) {
      throw ServerException('Failed to add vendor: ${e.toString()}');
    }
  }

  @override
  Future<void> updateVendor(VendorEntity vendor) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendor.id)
          .update(_toJson(vendor).toMap(vendor.id));
    } catch (e) {
      throw ServerException('Failed to update vendor: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteVendor(String id) async {
    try {
      await _firestore.collection('vendors').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete vendor: ${e.toString()}');
    }
  }

  VendorEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return VendorEntity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      contactPerson: data['contactPerson'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }

  _VendorJson _toJson(VendorEntity v) => _VendorJson(v);
}

class _VendorJson {
  final VendorEntity v;
  const _VendorJson(this.v);

  Map<String, dynamic> toMap(String id) => {
    'id': id,
    'name': v.name,
    'contactPerson': v.contactPerson,
    'phone': v.phone,
    'email': v.email,
    'notes': v.notes,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
