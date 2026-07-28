import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event_entity.dart';
import 'event_providers.dart';

class EventState {
  final List<EventEntity> events;
  final bool isLoading;
  final String? errorMessage;

  const EventState({
    this.events = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EventState copyWith({
    List<EventEntity>? events,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EventState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EventNotifier extends Notifier<EventState> {
  @override
  EventState build() {
    return const EventState();
  }

  Future<void> create(EventEntity event) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(eventRepositoryProvider);
      await repository.createEvent(event);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateStatus(String eventId, String status) async {
    try {
      final repository = ref.read(eventRepositoryProvider);
      final event = await repository.getEventById(eventId);
      if (event != null) {
        final updatedEvent = event.copyWith(status: status);
        await repository.updateEvent(updatedEvent);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateCompletion(String eventId, double completion) async {
    try {
      final repository = ref.read(eventRepositoryProvider);
      final event = await repository.getEventById(eventId);
      if (event != null) {
        final updatedEvent = event.copyWith(completion: completion);
        await repository.updateEvent(updatedEvent);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(eventRepositoryProvider);
      await repository.deleteEvent(eventId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final eventNotifierProvider = NotifierProvider<EventNotifier, EventState>(() {
  return EventNotifier();
});
