import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';

void showStaffLeaveRequestSheet(BuildContext context, WidgetRef ref) {
  final authState = ref.read(authNotifierProvider);
  final user = authState.user;
  if (user == null) return;

  final colorScheme = Theme.of(context).colorScheme;

  showLeaveRequestSheet(
    context: context,
    ref: ref,
    userId: user.uid,
    userEmail: user.email,
    primaryColor: colorScheme.primary,
    cardColor: colorScheme.surface,
    borderColor: colorScheme.outline,
    textColor: colorScheme.onSurface,
    labelColor: colorScheme.onSurfaceVariant,
  );
}

void showLeaveRequestSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required String userEmail,
  required Color primaryColor,
  required Color cardColor,
  required Color borderColor,
  required Color textColor,
  required Color labelColor,
}) {
  final staffName = userEmail.split('@').first;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 1));
  String leaveType = LeaveRequestEntity.availableLeaveTypes.first;
  final reasonController = TextEditingController();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Consumer(
            builder: (context, ref, child) {
              final profilesAsync = ref.watch(employeeProfilesStreamProvider);
              final leaveRequestsAsync = ref.watch(leaveRequestsStreamProvider);

              // Find the profile for the current user
              final profile = profilesAsync.maybeWhen(
                data: (list) {
                  final matching = list.where((p) => p.userId == userId);
                  if (matching.isNotEmpty) return matching.first;
                  return EmployeeProfileEntity(
                    id: '',
                    userId: userId,
                    name: staffName,
                    officeJoinDate: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                },
                orElse: () => null,
              );

              final myLeaveRequests = leaveRequestsAsync.maybeWhen(
                data: (list) => list
                    .where(
                      (l) =>
                          l.staffId == userId &&
                          l.status == LeaveStatus.approved,
                    )
                    .toList(),
                orElse: () => <LeaveRequestEntity>[],
              );

              // Calculate taken days
              int takenDays(String leaveType) {
                return myLeaveRequests
                    .where((l) => l.leaveType == leaveType)
                    .map((l) => l.endDate.difference(l.startDate).inDays + 1)
                    .fold(0, (sum, days) => sum + days);
              }

              final allowed =
                  profile?.effectiveAllowedLeaves[leaveType] ??
                  EmployeeProfileEntity.defaultAllowedLeaves[leaveType] ??
                  0;
              final taken = takenDays(leaveType);
              final remaining = (allowed - taken).clamp(0, allowed);
              final requestedDays = endDate.difference(startDate).inDays + 1;
              final exceedsBalance = requestedDays > remaining;

              return Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Request Leave / Off-Duty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: labelColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Leave Type',
                        style: TextStyle(fontSize: 12, color: labelColor),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: leaveType,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: LeaveRequestEntity.availableLeaveTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => leaveType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Leave Balance Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available Balance:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: labelColor,
                              ),
                            ),
                            Text(
                              '$remaining / $allowed Days Remaining',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (exceedsBalance) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Warning: Request ($requestedDays days) exceeds remaining balance ($remaining days).',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: Text(
                                    formatNepaliDate(startDate, 'dd MMM yyyy'),
                                  ),
                                  onPressed: () async {
                                    final picked = await NepaliDatePickerDialog.show(
                                      context: context,
                                      title: 'Select Leave Start Date (Nepali BS)',
                                      initialStart: startDate,
                                      allowRange: false,
                                    );
                                    if (picked != null && picked['start'] != null) {
                                      setSheetState(() {
                                        startDate = picked['start']!;
                                        if (endDate.isBefore(startDate)) {
                                          endDate = startDate.add(
                                            const Duration(days: 1),
                                          );
                                        }
                                      });
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
                                Text(
                                  'End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                  label: Text(
                                    formatNepaliDate(endDate, 'dd MMM yyyy'),
                                  ),
                                  onPressed: () async {
                                    final picked = await NepaliDatePickerDialog.show(
                                      context: context,
                                      title: 'Select Leave End Date (Nepali BS)',
                                      initialStart: endDate,
                                      allowRange: false,
                                    );
                                    if (picked != null && picked['start'] != null) {
                                      setSheetState(() => endDate = picked['start']!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reason / Remarks',
                        style: TextStyle(fontSize: 12, color: labelColor),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Provide details about your leave request...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: exceedsBalance
                                ? Colors.red
                                : primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  try {
                                    final request = LeaveRequestEntity(
                                      id: const Uuid().v4(),
                                      staffId: userId,
                                      staffName: staffName,
                                      startDate: startDate,
                                      endDate: endDate,
                                      leaveType: leaveType,
                                      reason: reasonController.text.trim(),
                                      createdAt: DateTime.now(),
                                    );

                                    await ref
                                        .read(
                                          leaveRequestNotifierProvider.notifier,
                                        )
                                        .submitLeave(request);

                                    // Dispatch notification to Admins
                                    await ref
                                        .read(
                                          notificationNotifierProvider.notifier,
                                        )
                                        .addNotification(
                                          NotificationEntity(
                                            id: const Uuid().v4(),
                                            title:
                                                'New Leave Request: $staffName',
                                            description:
                                                '$staffName requested $leaveType from ${formatNepaliDate(startDate, 'dd MMM')} to ${formatNepaliDate(endDate, 'dd MMM')}.',
                                            timestamp: DateTime.now(),
                                            type: 'system',
                                            targetRole: 'admin',
                                          ),
                                        );

                                    FcmSender.sendToTopic(
                                      topic: 'role_admin',
                                      title: 'New Leave Request: $staffName',
                                      body: '$staffName requested $leaveType.',
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Leave request submitted to Admin!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setSheetState(() => isSubmitting = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  exceedsBalance
                                      ? 'Request Leave (Exceeds Limit)'
                                      : 'Submit Leave Request',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'My Recent Leave Requests',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      leaveRequestsAsync.when(
                        data: (requests) {
                          final userRequests =
                              requests
                                  .where((r) => r.staffId == userId)
                                  .toList()
                                ..sort(
                                  (a, b) => b.createdAt.compareTo(a.createdAt),
                                );

                          if (userRequests.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                'No previous leave requests.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: labelColor,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: userRequests.take(5).map((req) {
                              Color statusColor;
                              switch (req.status) {
                                case LeaveStatus.approved:
                                  statusColor = Colors.green;
                                  break;
                                case LeaveStatus.rejected:
                                  statusColor = Colors.red;
                                  break;
                                case LeaveStatus.pending:
                                  statusColor = Colors.orange;
                                  break;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.leaveType,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${formatNepaliDate(req.startDate, 'dd MMM')} - ${formatNepaliDate(req.endDate, 'dd MMM yyyy')}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: labelColor,
                                            ),
                                          ),
                                          if (req.reason.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Reason: ${req.reason}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: labelColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        req.status.displayName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
