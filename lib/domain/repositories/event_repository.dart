import 'package:order_app/domain/entities/event_entity.dart';

abstract class EventRepository {
  Stream<List<EventEntity>> getEvents();
  Future<EventEntity?> getEventById(String id);
  Future<void> createEvent(EventEntity event);
  Future<void> updateEvent(EventEntity event);
  Future<void> deleteEvent(String id);
  Future<void> syncEventForOrder(dynamic order);
  Future<void> deleteEventsForOrder(String orderId);
}
