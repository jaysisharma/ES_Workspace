import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';

class FirestoreEventRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreEventRemoteDataSource(this._firestore);

  Stream<List<EventModel>> getEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EventModel.fromJson(data);
      }).toList();
    });
  }

  Future<void> createEvent(EventModel event) async {
    await _firestore
        .collection('events')
        .doc(event.id.isEmpty ? null : event.id)
        .set(event.toJson());
  }

  Future<void> updateEvent(EventModel event) async {
    await _firestore.collection('events').doc(event.id).update(event.toJson());
  }

  Future<void> deleteEvent(String id) async {
    await _firestore.collection('events').doc(id).delete();
  }

  Future<EventModel?> getEventById(String id) async {
    final doc = await _firestore.collection('events').doc(id).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return EventModel.fromJson(data);
    }
    return null;
  }
}
