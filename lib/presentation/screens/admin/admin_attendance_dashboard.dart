import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/attendance_entity.dart';
import '../../../core/services/geofence_service.dart';
import '../../providers/attendance_providers.dart';
import '../../providers/auth_provider.dart';
import '../staff/staff_attendance_screen.dart';
import '../../widgets/manage_geofence_dialog.dart';
import '../../widgets/calendar/nepali_date_picker_dialog.dart';
import '../../../core/utils/route_transitions.dart';

class AdminAttendanceDashboard extends ConsumerStatefulWidget {
  const AdminAttendanceDashboard({super.key});

  @override
  ConsumerState<AdminAttendanceDashboard> createState() =>
      _AdminAttendanceDashboardState();
}

class _AdminAttendanceDashboardState
    extends ConsumerState<AdminAttendanceDashboard> {
  DateTime _selectedDate = DateTime.now();
  bool _showOnlyOutOfBounds = false;
  final ScrollController _scrollController = ScrollController();
  int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _pageSize += 15;
      });
    }
  }

  void _showSelfieDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Image.network(
                imageUrl,
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey.shade300,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Selfie stored on Synology NAS'),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Stored on Synology NAS: $imageUrl',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceStream = ref.watch(allAttendanceStreamProvider);
    final currentUserId = ref.watch(authNotifierProvider).user?.uid ?? '';
    final todayAttendance = ref.watch(todayAttendanceStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Attendance & Geofence Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.touch_app, size: 16, color: Colors.white),
              label: const Text(
                'Mark My Attendance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: const StaffAttendanceScreen()),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_location_rounded),
            tooltip: 'Manage Geofence Zone',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ManageGeofenceDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allAttendanceStreamProvider),
          ),
        ],
      ),
      body: attendanceStream.when(
        data: (allRecords) {
          var filteredRecords = allRecords.where((r) {
            return r.checkInTime.year == _selectedDate.year &&
                r.checkInTime.month == _selectedDate.month &&
                r.checkInTime.day == _selectedDate.day;
          }).toList();

          if (_showOnlyOutOfBounds) {
            filteredRecords = filteredRecords
                .where((r) => !r.isWithinGeofence)
                .toList();
          }

          filteredRecords.sort(
            (a, b) => b.checkInTime.compareTo(a.checkInTime),
          );

          final onDutyCount = filteredRecords
              .where((r) => !r.isCheckedOut)
              .length;
          final presentCount = filteredRecords
              .where((r) => r.status == AttendanceStatus.present)
              .length;
          final outOfBoundsCount = allRecords
              .where((r) => !r.isWithinGeofence)
              .length;

          return Column(
            children: [
              // Metric Summary Cards & Geofence Filter
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
                child: Column(
                  children: [
                    // Admin Personal Attendance Status Banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'My Attendance Status',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                todayAttendance.when(
                                  data: (records) {
                                    final record = records
                                        .where((r) => r.staffId == currentUserId)
                                        .firstOrNull;
                                    if (record == null) {
                                      return const Text(
                                        'Not Clocked In Today',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.orange,
                                        ),
                                      );
                                    }
                                    if (!record.isCheckedOut) {
                                      return Text(
                                        'Clocked In at ${DateFormat('hh:mm a').format(record.checkInTime)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.green,
                                        ),
                                      );
                                    }
                                    return Text(
                                      'Clocked Out at ${DateFormat('hh:mm a').format(record.checkOutTime!)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.blue,
                                      ),
                                    );
                                  },
                                  loading: () => const Text(
                                    'Checking status...',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  error: (_, __) => const Text(
                                    'Not Clocked In',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                SlidePageRoute(
                                  page: const StaffAttendanceScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Mark / Manage',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Office Geofence Zone Banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pin_drop_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Office Geofence Zone',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Manage central GPS coordinates & radius',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => const ManageGeofenceDialog(),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              Icons.edit_location_alt_rounded,
                              size: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            label: Text(
                              'Manage Zone',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date Filter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Change Date'),
                          onPressed: () async {
                            final picked = await NepaliDatePickerDialog.show(
                              context: context,
                              title: 'Select Attendance Date (Nepali BS)',
                              initialStart: _selectedDate,
                              allowRange: false,
                            );
                            if (picked != null && picked['start'] != null) {
                              setState(() {
                                _selectedDate = picked['start']!;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildMetricChip(
                          context,
                          'Total Logs',
                          '${filteredRecords.length}',
                          Theme.of(context).colorScheme.primary,
                          false,
                        ),
                        _buildMetricChip(
                          context,
                          'On Duty',
                          '$onDutyCount',
                          Theme.of(context).colorScheme.secondary,
                          false,
                        ),
                        _buildMetricChip(
                          context,
                          'Present',
                          '$presentCount',
                          Theme.of(context).colorScheme.tertiary,
                          false,
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showOnlyOutOfBounds = !_showOnlyOutOfBounds;
                            });
                          },
                          child: _buildMetricChip(
                            context,
                            'Out of Fence',
                            '$outOfBoundsCount',
                            Theme.of(context).colorScheme.error,
                            _showOnlyOutOfBounds,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Attendance List
              Expanded(
                child: filteredRecords.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendance records found for this selection.',
                        ),
                      )
                    : () {
                        final hasMore = filteredRecords.length > _pageSize;
                        final currentLength = hasMore
                            ? _pageSize
                            : filteredRecords.length;

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: hasMore
                              ? currentLength + 1
                              : currentLength,
                          itemBuilder: (context, index) {
                            if (index == currentLength) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final item = filteredRecords[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.staffName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                item.eventTitle,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<AttendanceStatus>(
                                          initialValue: item.status,
                                          onSelected: (status) {
                                            ref
                                                .read(
                                                  attendanceNotifierProvider
                                                      .notifier,
                                                )
                                                .updateStatus(item.id, status);
                                          },
                                          itemBuilder: (context) =>
                                              AttendanceStatus.values.map((s) {
                                                return PopupMenuItem(
                                                  value: s,
                                                  child: Text(s.displayName),
                                                );
                                              }).toList(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                context,
                                                item.status,
                                              ).withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                  context,
                                                  item.status,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.status.displayName,
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                      context,
                                                      item.status,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.arrow_drop_down,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),

                                    // Timestamps & Location & Geofence Badge
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Clock In: ${DateFormat('MMM dd, hh:mm a').format(item.checkInTime)}',
                                              ),
                                              if (item.checkOutTime != null)
                                                Text(
                                                  'Clock Out: ${DateFormat('MMM dd, hh:mm a').format(item.checkOutTime!)}',
                                                ),
                                              if (item.checkInAddress !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        item.checkInAddress!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              // Geofence Audit Chip
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: item.isWithinGeofence
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .tertiaryContainer
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .errorContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      item.isWithinGeofence
                                                          ? Icons.verified
                                                          : Icons
                                                                .warning_amber_rounded,
                                                      size: 13,
                                                      color:
                                                          item.isWithinGeofence
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .onTertiaryContainer
                                                          : Theme.of(context)
                                                                .colorScheme
                                                                .onErrorContainer,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      item.isWithinGeofence
                                                          ? 'Geofence Verified On-Site'
                                                          : 'Out-of-Fence (${GeofenceService.formatDistance(item.distanceToVenueMeters)})',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            item.isWithinGeofence
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onTertiaryContainer
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onErrorContainer,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Synology Selfie Thumbnail Button
                                        if (item.checkInSelfieUrl != null)
                                          GestureDetector(
                                            onTap: () => _showSelfieDialog(
                                              context,
                                              item.checkInSelfieUrl!,
                                              '${item.staffName} Check-In Selfie',
                                            ),
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  width: 2,
                                                ),
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                    item.checkInSelfieUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) =>
            Center(child: Text('Error loading attendance logs: $e')),
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context,
    String label,
    String value,
    Color color, [
    bool isSelected = false,
  ]) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.25) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context, AttendanceStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case AttendanceStatus.present:
        return colorScheme.primary;
      case AttendanceStatus.late:
        return colorScheme.tertiary;
      case AttendanceStatus.absent:
        return colorScheme.error;
      case AttendanceStatus.halfDay:
        return colorScheme.secondary;
    }
  }
}
