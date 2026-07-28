import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/nepali_date_formatter.dart';
import '../../domain/entities/leave_request_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/hr_providers.dart';
import '../providers/order_providers.dart';

class StaffAssignmentDialog extends ConsumerStatefulWidget {
  final String orderId;
  final String eventTitle;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final List<String> currentAssignedStaffIds;
  final ValueChanged<List<String>> onSaved;

  const StaffAssignmentDialog({
    super.key,
    required this.orderId,
    required this.eventTitle,
    required this.eventDate,
    this.eventEndDate,
    required this.currentAssignedStaffIds,
    required this.onSaved,
  });

  @override
  ConsumerState<StaffAssignmentDialog> createState() =>
      _StaffAssignmentDialogState();
}

class _StaffAssignmentDialogState
    extends ConsumerState<StaffAssignmentDialog> {
  late List<String> _selectedStaffIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedStaffIds = List.from(widget.currentAssignedStaffIds);
  }

  bool _isDatesOverlapping(
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2.add(const Duration(days: 1))) &&
        end1.isAfter(start2.subtract(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    final usersAsync = ref.watch(usersStreamProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    final eventEnd = widget.eventEndDate ?? widget.eventDate;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Event Staff',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.eventTitle} • ${formatNepaliDate(widget.eventDate, 'dd MMM yyyy')}',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 450,
        child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (users) {
            final staffList =
                users.where((u) => u.role == UserRole.staff && u.isActive).toList();

            final leaveRequests = leaveRequestsAsync.maybeWhen(
              data: (list) => list,
              orElse: () => <LeaveRequestEntity>[],
            );

            final allOrders = ordersAsync.maybeWhen(
              data: (list) => list,
              orElse: () => <OrderEntity>[],
            );

            final filteredStaff = staffList.where((s) {
              return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.email.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            return Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search staff member...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredStaff.isEmpty
                      ? Center(
                          child: Text(
                            'No active staff members found',
                            style: TextStyle(color: labelColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredStaff.length,
                          itemBuilder: (context, index) {
                            final staff = filteredStaff[index];
                            final isSelected =
                                _selectedStaffIds.contains(staff.id);

                            // Check Leave Conflict
                            final activeLeave = leaveRequests.firstWhere(
                              (l) =>
                                  l.staffId == staff.id &&
                                  l.status == LeaveStatus.approved &&
                                  _isDatesOverlapping(widget.eventDate, eventEnd,
                                      l.startDate, l.endDate),
                              orElse: () => LeaveRequestEntity(
                                id: '',
                                staffId: '',
                                staffName: '',
                                startDate: DateTime.now(),
                                endDate: DateTime.now(),
                                leaveType: '',
                                reason: '',
                                createdAt: DateTime.now(),
                              ),
                            );
                            final hasLeaveConflict = activeLeave.id.isNotEmpty;

                            // Check Double-Booking Conflict
                            final conflictingOrder = allOrders.firstWhere(
                              (o) =>
                                  o.id != widget.orderId &&
                                  o.assignedStaffIds.contains(staff.id) &&
                                  (o.status == OrderStatus.confirmed ||
                                      o.status == OrderStatus.inProgress) &&
                                  _isDatesOverlapping(
                                      widget.eventDate,
                                      eventEnd,
                                      o.eventDate,
                                      o.eventEndDate ?? o.eventDate),
                              orElse: () => OrderEntity(
                                id: '',
                                eventName: '',
                                eventDate: DateTime.now(),
                                setupDate: DateTime.now(),
                                venue: '',
                                contactPerson: '',
                                contactNumber: '',
                                notes: '',
                                status: OrderStatus.draft,
                                assignedStaffIds: const [],
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              ),
                            );
                            final hasOrderConflict =
                                conflictingOrder.id.isNotEmpty;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: isSelected
                                  ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      staff.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (hasLeaveConflict)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 12,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'On Leave (${activeLeave.leaveType})',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (hasOrderConflict)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.event_busy,
                                              size: 12,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Assigned: ${conflictingOrder.eventName}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  staff.email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: labelColor,
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedStaffIds.add(staff.id);
                                      } else {
                                        _selectedStaffIds.remove(staff.id);
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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
          onPressed: () {
            widget.onSaved(_selectedStaffIds);
            Navigator.pop(context);
          },
          child: const Text('Save Assignments'),
        ),
      ],
    );
  }
}
