import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';

class DashboardStripState {
  final List<String> selectedEventIds;
  final bool isInitialized;

  const DashboardStripState({
    this.selectedEventIds = const [],
    this.isInitialized = false,
  });

  DashboardStripState copyWith({
    List<String>? selectedEventIds,
    bool? isInitialized,
  }) {
    return DashboardStripState(
      selectedEventIds: selectedEventIds ?? this.selectedEventIds,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class DashboardStripNotifier extends Notifier<DashboardStripState> {
  static const _selectedIdsPrefKey = 'dashboard_strip_selected_ids';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _firestoreSubscription;

  @override
  DashboardStripState build() {
    _init();
    ref.onDispose(() {
      _firestoreSubscription?.cancel();
    });
    return const DashboardStripState();
  }

  Future<void> _init() async {
    // 1. Instant local load for zero-flicker startup
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedIds = prefs.getStringList(_selectedIdsPrefKey) ?? [];
      state = DashboardStripState(
        selectedEventIds: selectedIds,
        isInitialized: true,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }

    // 2. Real-time Firestore sync so all users/devices see the exact same strip
    try {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = FirebaseFirestore.instance
          .collection('settings')
          .doc('dashboard_strip')
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data.containsKey('selectedEventIds')) {
            final remoteIds =
                List<String>.from(data['selectedEventIds'] ?? []);
            state = state.copyWith(
              selectedEventIds: remoteIds,
              isInitialized: true,
            );
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(_selectedIdsPrefKey, remoteIds);
          }
        }
      }, onError: (e) {
        debugPrint('Firestore dashboard_strip listener error: $e');
      });
    } catch (e) {
      debugPrint('Failed to attach Firestore dashboard_strip listener: $e');
    }
  }

  Future<void> toggleEventSelection(String eventId) async {
    final currentIds = List<String>.from(state.selectedEventIds);
    if (currentIds.contains(eventId)) {
      currentIds.remove(eventId);
    } else {
      currentIds.add(eventId);
    }
    await setSelectedEvents(currentIds);
  }

  Future<void> setSelectedEvents(List<String> eventIds) async {
    state = state.copyWith(selectedEventIds: eventIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefKey, eventIds);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('dashboard_strip')
          .set({
        'selectedEventIds': eventIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync dashboard_strip to Firestore: $e');
    }
  }

  Future<void> selectAllEvents(List<String> allIds) async {
    await setSelectedEvents(allIds);
  }

  Future<void> clearSelection() async {
    await setSelectedEvents([]);
  }

  /// Broadcasts both In-App & FCM Push Notifications to ALL users when new events are added to the strip
  static Future<void> notifyAllUsersOfStripEvents({
    required WidgetRef ref,
    required List<EventEntity> newlyAddedEvents,
  }) async {
    if (newlyAddedEvents.isEmpty) return;

    const allRoleTopics = [
      'all_users',
      'role_super_admin',
      'role_admin',
      'role_founder',
      'role_director',
      'role_company_secretary',
      'role_senior_staff',
      'role_finance',
      'role_staff',
    ];

    try {
      if (newlyAddedEvents.length == 1) {
        final event = newlyAddedEvents.first;
        final dateStr = formatNepaliDate(event.date, 'MMMM dd, yyyy');
        final title = '📢 Featured Event: ${event.title}';
        final description =
            '"${event.title}" on $dateStr has been added to the dashboard event strip.';
        final notificationId = const Uuid().v4();

        // 1. In-App Notification in Firestore for all users
        await ref
            .read(notificationNotifierProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: notificationId,
                title: title,
                description: description,
                timestamp: DateTime.now(),
                type: 'event',
                relatedId:
                    event.orderId.isNotEmpty ? event.orderId : event.id,
                targetRole: 'all',
              ),
            );

        // 2. Broadcast FCM Push Notification to all users
        FcmSender.sendToTopics(
          topics: allRoleTopics,
          title: title,
          body: description,
          notificationId: notificationId,
          data: {
            'type': 'event',
            'eventId': event.id,
            'orderId': event.orderId,
          },
        );
      } else {
        // Multiple events added at once
        final count = newlyAddedEvents.length;
        final eventTitles =
            newlyAddedEvents.take(3).map((e) => '"${e.title}"').join(', ');
        final title = '📢 $count Events Added to Dashboard Strip';
        final description = count > 3
            ? '$eventTitles and ${count - 3} more have been added to the dashboard event strip.'
            : '$eventTitles have been added to the dashboard event strip.';
        final notificationId = const Uuid().v4();

        // 1. In-App Notification in Firestore for all users
        await ref
            .read(notificationNotifierProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: notificationId,
                title: title,
                description: description,
                timestamp: DateTime.now(),
                type: 'event',
                relatedId: newlyAddedEvents.first.orderId.isNotEmpty
                    ? newlyAddedEvents.first.orderId
                    : newlyAddedEvents.first.id,
                targetRole: 'all',
              ),
            );

        // 2. Broadcast FCM Push Notification to all users
        FcmSender.sendToTopics(
          topics: allRoleTopics,
          title: title,
          body: description,
          notificationId: notificationId,
          data: {
            'type': 'event',
            'eventCount': count.toString(),
          },
        );
      }
      debugPrint(
        '🔔 [DashboardStripNotifier] Successfully notified all users of ${newlyAddedEvents.length} strip events',
      );
    } catch (e) {
      debugPrint('Failed to send strip event broadcast notification: $e');
    }
  }
}

final dashboardStripNotifierProvider =
    NotifierProvider<DashboardStripNotifier, DashboardStripState>(() {
  return DashboardStripNotifier();
});
