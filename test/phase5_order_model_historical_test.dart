import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_app/core/calendar/bs_calendar_service.dart';
import 'package:order_app/data/models/order_model.dart';
import 'package:order_app/domain/entities/order_entity.dart';

void main() {
  group('Phase 5 Order Model & Historical Data Backwards-Compatibility Tests', () {
    test('1. New order saves Firestore Timestamp as canonical date', () {
      final canonicalEventDate = BsCalendarService.bsToAd(2083, 6, 15);
      final canonicalSetupDate = BsCalendarService.bsToAd(2083, 6, 14);
      final canonicalEndDate = BsCalendarService.bsToAd(2083, 6, 17);
      final canonicalSetupEndDate = BsCalendarService.bsToAd(2083, 6, 15);

      final order = OrderModel(
        id: 'ORD-NEW-1',
        eventName: 'Annual Corporate Gala',
        eventDate: canonicalEventDate,
        eventEndDate: canonicalEndDate,
        setupDate: canonicalSetupDate,
        setupEndDate: canonicalSetupEndDate,
        venue: 'Kathmandu Ballroom',
        contactPerson: 'Bikash',
        contactNumber: '9841000000',
        notes: '',
        status: OrderStatus.confirmed,
        assignedStaffIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = order.toJson();

      // Canonical machine-readable dates must be Firestore Timestamps
      expect(json['eventDate'], isA<Timestamp>());
      expect(json['setupDate'], isA<Timestamp>());
      expect(json['eventEndDate'], isA<Timestamp>());
      expect(json['setupEndDate'], isA<Timestamp>());

      final eventTs = json['eventDate'] as Timestamp;
      expect(eventTs.toDate().year, 2026);
      expect(eventTs.toDate().month, 10);
      expect(eventTs.toDate().day, 1);

      // Backwards-compatible ISO strings and BS helper representations
      expect(json['eventDateIso'], isA<String>());
      expect(json['eventDateBs'], '2083-06-15');
      expect(json['setupDateBs'], '2083-06-14');
      expect(json['eventEndDateBs'], '2083-06-17');
      expect(json['setupEndDateBs'], '2083-06-15');
    });

    test('2. Existing historical order with ISO-8601 string still loads correctly', () {
      final legacyJson = {
        'id': 'ORD-LEGACY-ISO',
        'eventName': 'Historical Event',
        'eventDate': '2026-10-01T12:00:00.000',
        'setupDate': '2026-09-30T12:00:00.000',
        'venue': 'Heritage Hall',
        'contactPerson': 'Aayush',
        'contactNumber': '9812345678',
        'notes': 'Old order before refactor',
        'status': 'confirmed',
        'assignedStaffIds': <String>[],
        'createdAt': '2026-09-01T10:00:00.000',
        'updatedAt': '2026-09-01T10:00:00.000',
      };

      final loadedOrder = OrderModel.fromJson(legacyJson);

      expect(loadedOrder.id, 'ORD-LEGACY-ISO');
      expect(loadedOrder.eventDate.year, 2026);
      expect(loadedOrder.eventDate.month, 10);
      expect(loadedOrder.eventDate.day, 1);

      // Derived BS date is accurate without off-by-one errors
      expect(loadedOrder.eventDateBs, '2083-06-15');
      expect(loadedOrder.setupDateBs, '2083-06-14');
    });

    test('3. Order with Firestore Timestamp loads correctly', () {
      final tsJson = {
        'id': 'ORD-TIMESTAMP',
        'eventName': 'Timestamp Event',
        'eventDate': Timestamp.fromDate(DateTime(2026, 10, 1, 12, 0, 0)),
        'setupDate': Timestamp.fromDate(DateTime(2026, 9, 30, 12, 0, 0)),
        'venue': 'Central Plaza',
        'contactPerson': 'Rita',
        'contactNumber': '9800000000',
        'notes': '',
        'status': 'confirmed',
        'assignedStaffIds': <String>[],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      final loadedOrder = OrderModel.fromJson(tsJson);

      expect(loadedOrder.id, 'ORD-TIMESTAMP');
      expect(loadedOrder.eventDateBs, '2083-06-15');
      expect(loadedOrder.setupDateBs, '2083-06-14');
    });

    test('4. Order with epoch integer loads correctly', () {
      final epochJson = {
        'id': 'ORD-EPOCH',
        'eventName': 'Epoch Event',
        'eventDate': DateTime(2026, 10, 1, 12, 0, 0).millisecondsSinceEpoch,
        'setupDate': DateTime(2026, 9, 30, 12, 0, 0).millisecondsSinceEpoch,
        'venue': 'Tech Center',
        'contactPerson': 'Pradeep',
        'contactNumber': '9855555555',
        'notes': '',
        'status': 'confirmed',
        'assignedStaffIds': <String>[],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      final loadedOrder = OrderModel.fromJson(epochJson);

      expect(loadedOrder.id, 'ORD-EPOCH');
      expect(loadedOrder.eventDateBs, '2083-06-15');
      expect(loadedOrder.setupDateBs, '2083-06-14');
    });

    test('5. BS display from legacy midnight ISO string is protected from off-by-one shift', () {
      // Legacy systems often saved midnight strings '2026-10-01T00:00:00.000'
      final midnightJson = {
        'id': 'ORD-MIDNIGHT',
        'eventName': 'Midnight String Event',
        'eventDate': '2026-10-01T00:00:00.000',
        'setupDate': '2026-09-30T00:00:00.000',
        'venue': 'Venue',
        'contactPerson': 'Contact',
        'contactNumber': 'Phone',
        'notes': '',
        'status': 'confirmed',
        'assignedStaffIds': <String>[],
        'createdAt': '2026-09-01T00:00:00.000',
        'updatedAt': '2026-09-01T00:00:00.000',
      };

      final loadedOrder = OrderModel.fromJson(midnightJson);

      // Must reliably map to 2083-06-15 in Asia/Kathmandu
      expect(loadedOrder.eventDateBs, '2083-06-15');
      expect(loadedOrder.setupDateBs, '2083-06-14');
    });

    test('6. Editing legacy order safely upgrades it to canonical Firestore Timestamp on write', () {
      final legacyJson = {
        'id': 'ORD-EDIT-MIGRATE',
        'eventName': 'Legacy Event to Edit',
        'eventDate': '2026-10-01T12:00:00.000',
        'setupDate': '2026-09-30T12:00:00.000',
        'venue': 'Old Venue',
        'contactPerson': 'Sunil',
        'contactNumber': '9801234567',
        'notes': '',
        'status': 'confirmed',
        'assignedStaffIds': <String>[],
        'createdAt': '2026-09-01T10:00:00.000',
        'updatedAt': '2026-09-01T10:00:00.000',
      };

      // Load legacy order
      final legacyOrder = OrderModel.fromJson(legacyJson);
      expect(legacyOrder.eventDateBs, '2083-06-15');

      // User edits event date to 2083 Ashwin 20
      final newCanonicalDate = BsCalendarService.bsToAd(2083, 6, 20);
      final updatedOrder = OrderModel.fromEntity(
        legacyOrder.copyWith(
          eventDate: newCanonicalDate,
          venue: 'Grand New Venue',
          updatedAt: DateTime.now(),
        ),
      );

      // Save to Firestore payload
      final updatedJson = updatedOrder.toJson();

      // Canonical machine-readable date is now a Timestamp
      expect(updatedJson['eventDate'], isA<Timestamp>());
      final eventTs = updatedJson['eventDate'] as Timestamp;
      expect(eventTs.toDate().year, 2026);
      expect(eventTs.toDate().month, 10);
      expect(eventTs.toDate().day, 6);

      // Derived BS date helper is also updated
      expect(updatedJson['eventDateBs'], '2083-06-20');
      expect(updatedJson['venue'], 'Grand New Venue');
    });

    test('7. Multi-day event start and end dates remain consistent', () {
      final start = BsCalendarService.bsToAd(2083, 6, 15);
      final end = BsCalendarService.bsToAd(2083, 6, 18);

      final order = OrderModel(
        id: 'ORD-RANGE',
        eventName: 'Multi Day Fest',
        eventDate: start,
        eventEndDate: end,
        setupDate: start.subtract(const Duration(days: 1)),
        venue: 'Park',
        contactPerson: 'Karan',
        contactNumber: '9800000000',
        notes: '',
        status: OrderStatus.confirmed,
        assignedStaffIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = order.toJson();
      expect(json['eventDate'], isA<Timestamp>());
      expect(json['eventEndDate'], isA<Timestamp>());

      final reloaded = OrderModel.fromJson(json);
      expect(reloaded.eventDateBs, '2083-06-15');
      expect(reloaded.eventEndDateBs, '2083-06-18');
    });

    test('8. Setup start and end dates remain consistent', () {
      final setupStart = BsCalendarService.bsToAd(2083, 6, 13);
      final setupEnd = BsCalendarService.bsToAd(2083, 6, 14);
      final eventStart = BsCalendarService.bsToAd(2083, 6, 15);

      final order = OrderModel(
        id: 'ORD-SETUP-RANGE',
        eventName: 'Setup Heavy Event',
        eventDate: eventStart,
        setupDate: setupStart,
        setupEndDate: setupEnd,
        venue: 'Exhibition Hall',
        contactPerson: 'Manoj',
        contactNumber: '9800000000',
        notes: '',
        status: OrderStatus.confirmed,
        assignedStaffIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = order.toJson();
      expect(json['setupDate'], isA<Timestamp>());
      expect(json['setupEndDate'], isA<Timestamp>());

      final reloaded = OrderModel.fromJson(json);
      expect(reloaded.setupDateBs, '2083-06-13');
      expect(reloaded.setupEndDateBs, '2083-06-14');
      expect(reloaded.eventDateBs, '2083-06-15');
    });
  });
}
