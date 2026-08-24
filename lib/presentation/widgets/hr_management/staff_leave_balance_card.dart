import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';

class StaffLeaveBalanceCard extends ConsumerStatefulWidget {
  final String? customUserId;
  final bool showRecentRequests;

  const StaffLeaveBalanceCard({
    super.key,
    this.customUserId,
    this.showRecentRequests = true,
  });

  @override
  ConsumerState<StaffLeaveBalanceCard> createState() =>
      _StaffLeaveBalanceCardState();
}

class _StaffLeaveBalanceCardState extends ConsumerState<StaffLeaveBalanceCard> {
  bool _showAllTypes = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final authUser = ref.watch(authNotifierProvider).user;
    final targetUserId = widget.customUserId ?? authUser?.uid ?? '';
    if (targetUserId.isEmpty) return const SizedBox.shrink();

    final currentProfile = ref.watch(currentEmployeeProfileProvider);
    final settings = ref.watch(settingsProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsStreamProvider);

    final profile = currentProfile ??
        EmployeeProfileEntity(
          id: targetUserId,
          userId: targetUserId,
          name: authUser?.email.split('@').first ?? 'Staff',
          officeJoinDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final cycleLabel = NepaliCalendarEngine.getLeaveCycleLabel(
      cycleType: settings.leaveResetCycle,
      manualStartDate: settings.customLeaveCycleStartDate,
    );

    final effectiveAllocations = profile.effectiveAllowedLeaves;

    // Filter approved leaves for current cycle
    final approvedLeavesInCycle = leaveRequestsAsync.maybeWhen(
      data: (list) => list
          .where(
            (l) =>
                l.staffId == targetUserId &&
                l.status == LeaveStatus.approved &&
                NepaliCalendarEngine.isWithinActiveLeaveCycle(
                  l.startDate,
                  cycleType: settings.leaveResetCycle,
                  manualStartDate: settings.customLeaveCycleStartDate,
                ),
          )
          .toList(),
      orElse: () => <LeaveRequestEntity>[],
    );

    // All my leave requests (recent history)
    final myRecentRequests = leaveRequestsAsync.maybeWhen(
      data: (list) => list
          .where((l) => l.staffId == targetUserId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      orElse: () => <LeaveRequestEntity>[],
    );

    int takenDays(String leaveType) {
      return approvedLeavesInCycle
          .where((l) => l.leaveType == leaveType)
          .map((l) => l.endDate.difference(l.startDate).inDays + 1)
          .fold(0, (sum, days) => sum + days);
    }

    int totalAllowed = 0;
    int totalTaken = 0;
    effectiveAllocations.forEach((key, allowed) {
      totalAllowed += allowed;
      totalTaken += takenDays(key);
    });
    final totalRemaining = (totalAllowed - totalTaken).clamp(0, totalAllowed);

    final primaryColor = const Color(0xFF0075db);
    final cardBgColor = isDark ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);
    final labelColor = colorScheme.onSurfaceVariant;
    final textColor = colorScheme.onSurface;

    final leaveEntries = effectiveAllocations.entries.toList();
    final displayedEntries = _showAllTypes
        ? leaveEntries
        : leaveEntries.take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: primaryColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.time_to_leave_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Entitlements & Balances',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active Cycle: $cycleLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Apply',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => showStaffLeaveRequestSheet(context, ref),
                ),
              ],
            ),
          ),

          // Total Summary KPI row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                    : const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Allocated',
                      value: '$totalAllowed Days',
                      color: primaryColor,
                      labelColor: labelColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: borderColor,
                  ),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Taken',
                      value: '$totalTaken Days',
                      color: totalTaken > (totalAllowed * 0.8)
                          ? Colors.redAccent
                          : const Color(0xFFf59e0b),
                      labelColor: labelColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: borderColor,
                  ),
                  Expanded(
                    child: _buildSummaryMetric(
                      label: 'Remaining',
                      value: '$totalRemaining Days',
                      color: const Color(0xFF10b981),
                      labelColor: labelColor,
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Specific Leave Types
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isMobile ? 3.4 : 2.5,
                  ),
                  itemCount: displayedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = displayedEntries[index];
                    final leaveType = entry.key;
                    final allowed = entry.value;
                    final taken = takenDays(leaveType);
                    final remaining = (allowed - taken).clamp(0, allowed);
                    final percent =
                        allowed > 0 ? (taken / allowed).clamp(0.0, 1.0) : 0.0;

                    final Color statusColor = percent >= 1.0
                        ? Colors.red
                        : percent > 0.65
                            ? const Color(0xFFf59e0b)
                            : const Color(0xFF10b981);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.18)
                            : Colors.grey.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  leaveType,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '$remaining Left',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 5,
                              backgroundColor: borderColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Used: $taken / $allowed days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: labelColor,
                                ),
                              ),
                              Text(
                                '${((1.0 - percent) * 100).toInt()}% avail',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (leaveEntries.length > 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    _showAllTypes
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _showAllTypes
                        ? 'Show Less'
                        : 'View All Leaves (${leaveEntries.length})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() => _showAllTypes = !_showAllTypes);
                  },
                ),
              ),
            ),

          // Recent Requests Section
          if (widget.showRecentRequests && myRecentRequests.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Leave Requests',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${myRecentRequests.length} total',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: myRecentRequests.take(3).length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final req = myRecentRequests[index];
                final days = req.endDate.difference(req.startDate).inDays + 1;

                Color badgeColor;
                switch (req.status) {
                  case LeaveStatus.approved:
                    badgeColor = const Color(0xFF10b981);
                    break;
                  case LeaveStatus.rejected:
                    badgeColor = Colors.redAccent;
                    break;
                  case LeaveStatus.pending:
                    badgeColor = const Color(0xFFf59e0b);
                    break;
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.15)
                        : const Color(0xFFf8fafc),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          req.status == LeaveStatus.approved
                              ? Icons.check_circle_outline_rounded
                              : req.status == LeaveStatus.rejected
                                  ? Icons.cancel_outlined
                                  : Icons.hourglass_top_rounded,
                          size: 16,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  req.leaveType,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '($days ${days == 1 ? 'day' : 'days'})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: labelColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatNepaliDate(req.startDate, 'MMM dd')} – ${formatNepaliDate(req.endDate, 'MMM dd, yyyy')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          req.status.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
    required Color labelColor,
    bool isBold = false,
  }) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
