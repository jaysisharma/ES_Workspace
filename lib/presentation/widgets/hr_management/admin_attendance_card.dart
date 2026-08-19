import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/core/services/geofence_service.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';

class AdminAttendanceCardWidget extends StatelessWidget {
  final AttendanceEntity item;
  final ValueChanged<AttendanceStatus> onStatusChanged;
  final VoidCallback onSelfieTap;

  const AdminAttendanceCardWidget({
    super.key,
    required this.item,
    required this.onStatusChanged,
    required this.onSelfieTap,
  });

  Color _getStatusColor(BuildContext context, AttendanceStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case AttendanceStatus.present:
        return colorScheme.primary;
      case AttendanceStatus.absent:
        return colorScheme.error;
      case AttendanceStatus.halfDay:
        return colorScheme.secondary;
    }
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'In Progress';
    final diff = end.difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes.remainder(60);
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(context, item.status);
    final nepaliDateStr = formatNepaliDate(item.checkInTime, 'yyyy MMMM dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.staffName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (item.eventTitle.isNotEmpty)
                        Text(
                          item.eventTitle,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<AttendanceStatus>(
                  initialValue: item.status,
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => AttendanceStatus.values.map((s) {
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
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Nepali Date Badge (BS Date)
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$nepaliDateStr BS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Clock-In / Out Timestamps
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'In: ${DateFormat('hh:mm a').format(item.checkInTime)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.checkOutTime != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Duration Worked
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Duration: ${_formatDuration(item.checkInTime, item.checkOutTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      if (item.checkInAddress != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.checkInAddress!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Geofence Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.isWithinGeofence
                              ? colorScheme.tertiaryContainer
                              : colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isWithinGeofence
                                  ? Icons.verified
                                  : Icons.warning_amber_rounded,
                              size: 13,
                              color: item.isWithinGeofence
                                  ? colorScheme.onTertiaryContainer
                                  : colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.isWithinGeofence
                                  ? 'Geofence Verified On-Site'
                                  : 'Out-of-Fence (${GeofenceService.formatDistance(item.distanceToVenueMeters)})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isWithinGeofence
                                    ? colorScheme.onTertiaryContainer
                                    : colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (item.checkInSelfieUrl != null) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onSelfieTap,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(item.checkInSelfieUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
