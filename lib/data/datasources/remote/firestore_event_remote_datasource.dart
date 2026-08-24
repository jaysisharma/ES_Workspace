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

  Future<void> syncEventForOrder(dynamic order) async {
    try {
      final orderId = order.id.toString();
      final query = await _firestore
          .collection('events')
          .where('orderId', isEqualTo: orderId)
          .get();

      final String status = order.status.toString().contains('completed')
          ? 'Completed'
          : (order.status.toString().contains('inProgress')
              ? 'In Progress'
              : 'Upcoming');
      final double completion =
          order.status.toString().contains('completed') ? 1.0 : 0.0;

      if (query.docs.isNotEmpty) {
        for (final doc in query.docs) {
          await doc.reference.update({
            'title': order.eventName,
            'date': order.eventDate.toIso8601String(),
            'location': order.venue,
            'status': status,
            'completion': completion,
            'isArchived': order.isArchived,
          });
        }
      } else if (!order.status.toString().contains('draft')) {
        final newDoc = _firestore.collection('events').doc();
        final event = EventModel(
          id: newDoc.id,
          orderId: orderId,
          title: order.eventName,
          date: order.eventDate,
          location: order.venue,
          role: 'Lead Tech',
          status: status,
          completion: completion,
          isArchived: order.isArchived,
          createdAt: order.createdAt ?? order.eventDate,
        );
        await newDoc.set(event.toJson());
      }
    } catch (_) {}
  }

  Future<void> deleteEventsForOrder(String orderId) async {
    try {
      final query = await _firestore
          .collection('events')
          .where('orderId', isEqualTo: orderId)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }
}
