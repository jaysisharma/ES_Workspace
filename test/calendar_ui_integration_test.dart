import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/bs_calendar_service.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_calendar_view.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';

void main() {
  group('Calendar UI & Integration Tests (Phase 3 & 4)', () {
    testWidgets('2083 Bhadra last valid day is 31 and 32 does not render', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      NepaliDateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NepaliCalendarView(
                selectedDate: NepaliDateTime(2083, 5, 15),
                onDateSelected: (d) => selectedDate = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bhadra 2083 has 31 days
      expect(BsCalendarService.getDaysInMonth(2083, 5), 31);

      // Verify cell 31 exists in UI
      expect(find.text('31'), findsOneWidget);

      // Verify cell 32 does NOT exist anywhere in the widget tree
      expect(find.text('32'), findsNothing);

      // Tap day 31
      await tester.tap(find.text('31'));
      await tester.pumpAndSettle();

      expect(selectedDate, isNotNull);
      expect(selectedDate!.year, 2083);
      expect(selectedDate!.month, 5);
      expect(selectedDate!.day, 31);

      // Canonical AD conversion of 2083 Bhadra 31 is 2026-09-16
      final canonicalAd = BsCalendarService.bsToAd(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      expect(canonicalAd.year, 2026);
      expect(canonicalAd.month, 9);
      expect(canonicalAd.day, 16);
    });

    testWidgets('2083 Ashwin first day is 1 and maps to 2026-09-17', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      NepaliDateTime? selectedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NepaliCalendarView(
                selectedDate: NepaliDateTime(2083, 6, 1),
                onDateSelected: (d) => selectedDate = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(BsCalendarService.getDaysInMonth(2083, 6), 31);
      expect(find.text('1'), findsWidgets);

      final canonicalAd = BsCalendarService.bsToAd(2083, 6, 1);
      expect(canonicalAd.year, 2026);
      expect(canonicalAd.month, 9);
      expect(canonicalAd.day, 17);
    });

    testWidgets('Month navigation: switching Bhadra to Ashwin correctly updates view', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      NepaliDateTime? monthChangedDate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NepaliCalendarView(
                selectedDate: NepaliDateTime(2083, 5, 1),
                onMonthChanged: (d) => monthChangedDate = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bhadra'), findsOneWidget);

      // Tap next month icon
      final nextMonthBtn = find.byIcon(Icons.chevron_right_rounded);
      expect(nextMonthBtn, findsOneWidget);
      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      expect(monthChangedDate, isNotNull);
      expect(monthChangedDate!.year, 2083);
      expect(monthChangedDate!.month, 6);
      expect(find.textContaining('Ashwin'), findsOneWidget);
    });

    testWidgets('NepaliDatePickerDialog selection returns canonical DateTime via BsCalendarService', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, DateTime?>? pickedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  pickedResult = await NepaliDatePickerDialog.show(
                    context: context,
                    title: 'Select Event Date',
                    initialStart: BsCalendarService.bsToAd(2083, 6, 15),
                    allowRange: false,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Event Date'), findsOneWidget);

      // Select Day 20
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(pickedResult, isNotNull);
      final start = pickedResult!['start'];
      expect(start, isNotNull);

      // Canonical AD date for 2083 Ashwin 20
      final expectedAd = BsCalendarService.bsToAd(2083, 6, 20);
      expect(start!.year, expectedAd.year);
      expect(start.month, expectedAd.month);
      expect(start.day, expectedAd.day);
      expect(start.hour, 12); // midday anchor

      // Verify reverse conversion is exact
      final reconvertedBs = BsCalendarService.adToBs(start);
      expect(reconvertedBs, const BsDate(2083, 6, 20));
    });

    test('Event Order creation and editing flow with canonical dates', () {
      // 1. User selects 2083 Ashwin 15
      final canonicalCreationDate = BsCalendarService.bsToAd(2083, 6, 15);
      expect(canonicalCreationDate.year, 2026);
      expect(canonicalCreationDate.month, 10);
      expect(canonicalCreationDate.day, 1);

      // 2. Event Order Entity is created
      final order = OrderEntity(
        id: 'ORD-TEST-1',
        eventName: 'Tech Summit 2083',
        eventDate: canonicalCreationDate,
        setupDate: canonicalCreationDate.subtract(const Duration(days: 1)),
        venue: 'Kathmandu Hall',
        contactPerson: 'Suman',
        contactNumber: '9800000000',
        notes: '',
        status: OrderStatus.confirmed,
        assignedStaffIds: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Display BS date on Order Details
      final displayedBsDate = BsCalendarService.formatBs(order.eventDate, pattern: 'yyyy-MM-dd');
      expect(displayedBsDate, '2083-06-15');

      // 4. Editing order: user changes BS date from 2083 Ashwin 15 to 2083 Ashwin 20
      final newCanonicalDate = BsCalendarService.bsToAd(2083, 6, 20);
      final updatedOrder = order.copyWith(
        eventDate: newCanonicalDate,
        updatedAt: DateTime.now(),
      );

      // 5. Verify updated canonical date and displayed BS date
      expect(updatedOrder.eventDate.year, 2026);
      expect(updatedOrder.eventDate.month, 10);
      expect(updatedOrder.eventDate.day, 6);

      final updatedDisplayedBs = BsCalendarService.formatBs(updatedOrder.eventDate, pattern: 'yyyy-MM-dd');
      expect(updatedDisplayedBs, '2083-06-20');
    });
  });
}
