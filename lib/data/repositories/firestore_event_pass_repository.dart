import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/event_pass_entity.dart';
import 'package:order_app/domain/repositories/event_pass_repository.dart';
import 'package:order_app/core/errors/failures.dart';

class FirestoreEventPassRepository implements EventPassRepository {
  final FirebaseFirestore _firestore;

  FirestoreEventPassRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<EventPassEntity>> getAllPasses() async {
    try {
      final snapshot = await _firestore
          .collection('event_passes')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to load event passes: ${e.toString()}');
    }
  }

  @override
  Future<void> addPass(EventPassEntity pass) async {
    try {
      await _firestore.collection('event_passes').doc(pass.id).set(pass.toMap());
    } catch (e) {
      throw ServerException('Failed to add event pass: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePass(String id) async {
    try {
      await _firestore.collection('event_passes').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete event pass: ${e.toString()}');
    }
  }

  @override
  Future<EventPassEntity?> getPassById(String id) async {
    try {
      final doc = await _firestore.collection('event_passes').doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return _fromDoc(doc);
    } catch (e) {
      throw ServerException('Failed to fetch pass: ${e.toString()}');
    }
  }

  @override
  Future<void> redeemService(String passId, String serviceName) async {
    try {
      final docRef = _firestore.collection('event_passes').doc(passId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw ServerException('Event pass not found');
        }
        final data = snapshot.data() as Map<String, dynamic>;
        final pass = EventPassEntity.fromMap(data);

        bool found = false;
        final updatedServices = pass.services.map((service) {
          if (service.name == serviceName) {
            found = true;
            if (service.isRedeemed) {
              throw ServerException('Service has already been redeemed');
            }
            return service.copyWith(isRedeemed: true, redeemedAt: DateTime.now());
          }
          return service;
        }).toList();

        if (!found) {
          throw ServerException('Service not found on this pass');
        }

        transaction.update(docRef, {
          'services': updatedServices.map((s) => s.toMap()).toList(),
        });
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to redeem service: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getAvailableServices() async {
    try {
      final snapshot = await _firestore.collection('event_services').get();
      if (snapshot.docs.isEmpty) {
        final defaults = ['Dinner', 'Lunch', 'Drinks', 'Photoshoot'];
        for (final name in defaults) {
          await _firestore.collection('event_services').doc(name).set({'name': name});
        }
        return defaults;
      }
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      throw ServerException('Failed to load services: ${e.toString()}');
    }
  }

  @override
  Future<void> saveAvailableService(String serviceName) async {
    try {
      await _firestore
          .collection('event_services')
          .doc(serviceName)
          .set({'name': serviceName});
    } catch (e) {
      throw ServerException('Failed to save service: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAvailableService(String serviceName) async {
    try {
      await _firestore.collection('event_services').doc(serviceName).delete();
    } catch (e) {
      throw ServerException('Failed to delete service: ${e.toString()}');
    }
  }

  @override
  Future<String> getSecuritySalt() async {
    try {
      final doc = await _firestore.collection('event_settings').doc('config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('salt')) {
          return data['salt'] as String;
        }
      }
      final String newSalt = 'salt_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('event_settings').doc('config').set({'salt': newSalt});
      return newSalt;
    } catch (e) {
      throw ServerException('Failed to get security salt: ${e.toString()}');
    }
  }

  EventPassEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return EventPassEntity.fromMap({...data, 'id': doc.id});
  }
}
