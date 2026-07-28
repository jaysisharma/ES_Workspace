import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import '../../core/utils/nepali_date_formatter.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/attendance_providers.dart';
import '../providers/hr_providers.dart';
import '../providers/order_providers.dart';

class AdminManualAttendanceDialog extends ConsumerStatefulWidget {
  const AdminManualAttendanceDialog({super.key});

  @override
  ConsumerState<AdminManualAttendanceDialog> createState() =>
      _AdminManualAttendanceDialogState();
}

class _AdminManualAttendanceDialogState
    extends ConsumerState<AdminManualAttendanceDialog> {
  UserEntity? _selectedUser;
  OrderEntity? _selectedEvent;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _checkInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _checkOutTime = const TimeOfDay(hour: 17, minute: 0);
  bool _includeCheckOut = true;

  AttendanceStatus _status = AttendanceStatus.present;
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final textColor = colorScheme.onSurface;

    final usersAsync = ref.watch(usersStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Manual Attendance Entry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: labelColor),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Staff Member Picker
              Text('Select Staff Member',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor)),
              const SizedBox(height: 4),
              usersAsync.when(
                data: (users) {
                  final activeUsers = users.where((u) => u.isActive).toList();
                  return DropdownButtonFormField<UserEntity>(
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Select Employee'),
                    initialValue: _selectedUser,
                    items: activeUsers
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text('${u.name} (${u.role.name.toUpperCase()})'),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedUser = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading users: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 14),

              // 2. Event / Shift Picker
              Text('Select Event / Shift',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor)),
              const SizedBox(height: 4),
              ordersAsync.when(
                data: (orders) {
                  return DropdownButtonFormField<OrderEntity?>(
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('General Office Shift (Default)'),
                    initialValue: _selectedEvent,
                    items: [
                      const DropdownMenuItem<OrderEntity?>(
                        value: null,
                        child: Text('General Office Shift'),
                      ),
                      ...orders.map((o) => DropdownMenuItem<OrderEntity?>(
                            value: o,
                            child: Text('${o.eventName} (ID: ${o.id.substring(0, 8)})'),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedEvent = val),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),

              // 3. Date Picker (Nepali BS Calendar)
              Text('Attendance Date (BS Calendar)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor)),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(formatNepaliDate(_selectedDate, 'dd MMM yyyy (BS)')),
                onPressed: () async {
                  final picked = await showMaterialDatePicker(
                    context: context,
                    initialDate: _selectedDate.toNepaliDateTime(),
                    firstDate: NepaliDateTime(2070, 1, 1),
                    lastDate: NepaliDateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked.toDateTime());
                  }
                },
              ),
              const SizedBox(height: 14),

              // 4. Attendance Status
              Text('Attendance Status',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor)),
              const SizedBox(height: 4),
              DropdownButtonFormField<AttendanceStatus>(
                initialValue: _status,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: AttendanceStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s == AttendanceStatus.present
                                      ? Colors.green
                                      : s == AttendanceStatus.late
                                          ? Colors.orange
                                          : Colors.red)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 14),

              // 5. Check-In & Check-Out Times
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Check-in Time',
                            style: TextStyle(fontSize: 12, color: labelColor)),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(_checkInTime.format(context)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _checkInTime,
                            );
                            if (picked != null) {
                              setState(() => _checkInTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Check-out Time',
                                style: TextStyle(fontSize: 12, color: labelColor)),
                            Checkbox(
                              value: _includeCheckOut,
                              onChanged: (val) =>
                                  setState(() => _includeCheckOut = val ?? true),
                            ),
                          ],
                        ),
                        if (_includeCheckOut)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_filled, size: 16),
                            label: Text(_checkOutTime?.format(context) ?? '05:00 PM'),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _checkOutTime ??
                                    const TimeOfDay(hour: 17, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => _checkOutTime = picked);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 6. Admin Remarks
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Admin Remarks / Justification',
                  hintText: 'e.g. Manual entry recorded for Event Shift setup',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _saveManualAttendance,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Attendance Record'),
        ),
      ],
    );
  }

  Future<void> _saveManualAttendance() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final checkInDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _checkInTime.hour,
        _checkInTime.minute,
      );

      DateTime? checkOutDateTime;
      if (_includeCheckOut && _checkOutTime != null) {
        checkOutDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _checkOutTime!.hour,
          _checkOutTime!.minute,
        );
      }

      final attendanceRecord = AttendanceEntity(
        id: const Uuid().v4(),
        staffId: _selectedUser!.id,
        staffName: _selectedUser!.name,
        eventId: _selectedEvent?.id ?? 'general_shift',
        eventTitle: _selectedEvent?.eventName ?? 'General Office Shift',
        orderId: _selectedEvent?.id ?? '',
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        checkInTime: checkInDateTime,
        checkOutTime: checkOutDateTime,
        status: _status,
        notes: _notesController.text.trim().isNotEmpty
            ? 'Manual Entry: ${_notesController.text.trim()}'
            : 'Manual Entry by Admin',
        verifiedByQr: true,
        isWithinGeofence: true,
        createdAt: DateTime.now(),
      );

      await ref
          .read(attendanceRepositoryProvider)
          .checkIn(attendanceRecord);

      ref.invalidate(todayAttendanceStreamProvider);
      ref.invalidate(allAttendanceStreamProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Manual attendance recorded for ${_selectedUser!.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
