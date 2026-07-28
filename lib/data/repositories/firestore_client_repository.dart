import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/client_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../../core/errors/failures.dart';

class FirestoreClientRepository implements ClientRepository {
  final FirebaseFirestore _firestore;

  FirestoreClientRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ClientEntity>> getAllClients() async {
    try {
      final snapshot = await _firestore
          .collection('clients')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to get clients: ${e.toString()}');
    }
  }

  @override
  Future<void> addClient(ClientEntity client) async {
    try {
      final docRef = _firestore.collection('clients').doc();
      await docRef.set(_toJson(client.copyWith()).toMap(docRef.id));
    } catch (e) {
      throw ServerException('Failed to add client: ${e.toString()}');
    }
  }

  @override
  Future<void> updateClient(ClientEntity client) async {
    try {
      await _firestore
          .collection('clients')
          .doc(client.id)
          .update(_toJson(client).toMap(client.id));
    } catch (e) {
      throw ServerException('Failed to update client: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteClient(String id) async {
    try {
      await _firestore.collection('clients').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete client: ${e.toString()}');
    }
  }

  ClientEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ClientEntity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      contactPerson: data['contactPerson'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }

  _ClientJson _toJson(ClientEntity v) => _ClientJson(v);
}

class _ClientJson {
  final ClientEntity v;
  const _ClientJson(this.v);

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
