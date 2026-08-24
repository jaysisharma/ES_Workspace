import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/screens/admin/add_employee_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/common/events/event_task_detail_screen.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_profile_screen.dart';
import 'package:order_app/presentation/screens/staff/tasks_screen.dart';
import 'package:order_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:flutter/services.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/presentation/widgets/dashboard/this_week_events_strip.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  static bool _hasPromptedKycPopup = false;

  bool _isProfileComplete(EmployeeProfileEntity? profile) {
    if (profile == null) return false;
    final hasName = profile.name.trim().isNotEmpty;
    final hasAddress = profile.address.trim().isNotEmpty;
    final hasBloodGroup =
        profile.bloodGroup.trim().isNotEmpty && profile.bloodGroup != 'N/A';
    final hasFatherOrMother =
        profile.fatherName.trim().isNotEmpty ||
        profile.motherName.trim().isNotEmpty;
    final hasDob = profile.dob != null;
    final hasCitizenshipOrPan =
        profile.citizenshipNumber.trim().isNotEmpty ||
        profile.panNumber.trim().isNotEmpty ||
        profile.ninNumber.trim().isNotEmpty;

    return hasName &&
        hasAddress &&
        hasBloodGroup &&
        hasFatherOrMother &&
        hasDob &&
        hasCitizenshipOrPan;
  }

  void _checkAndShowKycPopup(
    BuildContext context,
    EmployeeProfileEntity? profile,
    dynamic user,
  ) {
    if (_hasPromptedKycPopup || user == null) return;
    final isComplete = _isProfileComplete(profile);
    if (!isComplete) {
      _hasPromptedKycPopup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showKycPromptDialog(context, profile, user);
      });
    }
  }

  void _showKycPromptDialog(
    BuildContext context,
    EmployeeProfileEntity? profile,
    dynamic user,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final cardBgColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final email = user?.email ?? '';
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : (email.isNotEmpty ? email.split('@').first : 'Staff');

    final missingList = <String>[];
    if (profile == null || profile.address.trim().isEmpty)
      missingList.add('🏠 Address');
    if (profile == null ||
        profile.bloodGroup.trim().isEmpty ||
        profile.bloodGroup == 'N/A')
      missingList.add('🩸 Blood Group');
    if (profile == null || profile.dob == null)
      missingList.add('📅 Date of Birth');
    if (profile == null ||
        (profile.fatherName.trim().isEmpty &&
            profile.motherName.trim().isEmpty))
      missingList.add('👨‍👩‍👧 Family Info');
    if (profile == null ||
        (profile.citizenshipNumber.trim().isEmpty &&
            profile.panNumber.trim().isEmpty &&
            profile.ninNumber.trim().isEmpty))
      missingList.add('🆔 Citizenship / PAN');
    if (profile == null ||
        profile.photoUrl == null ||
        profile.photoUrl!.trim().isEmpty)
      missingList.add('📷 Photo');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFf59e0b).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: Color(0xFFf59e0b),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Manrope',
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'KYC & Personal Information Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome! Some required employee details and KYC documents are missing from your profile. Please take a moment to update them.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: textColor.withValues(alpha: 0.9),
              ),
            ),
            if (missingList.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Missing Details:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: missingList
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF141f28)
                              : const Color(0xFFf1f5f9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF334155)
                                : const Color(0xFFcbd5e1),
                          ),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Later',
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                SlidePageRoute(
                  page: AddEmployeeScreen(
                    userId: user.uid,
                    userName: name,
                    userEmail: email,
                    userRole: UserRole.staff,
                    isStaffSelfEdit: true,
                    initialProfile: profile,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text(
              'Fill Details Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0b1319)
        : const Color(0xFFf8fafc);
    final cardBgColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);
    final textMuted = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final notificationState = ref.watch(notificationsStreamProvider);
    final profilesAsync = ref.watch(employeeProfilesStreamProvider);

    final myProfile = ref.watch(currentEmployeeProfileProvider);

    // Trigger popup on initial load if profile is incomplete
    profilesAsync.whenData((_) {
      _checkAndShowKycPopup(context, myProfile, user);
    });

    final unreadCount = notificationState.maybeWhen(
      data: (list) => list.where((n) => !n.isReadForUser(user?.id)).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Branding, Greeting & Actions
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isMobile = headerConstraints.maxWidth < 650;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      // Greeting & Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'ES Workspace',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isMobile ? 17 : 20,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Manrope',
                                      letterSpacing: -0.5,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'STAFF',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hello, ${user?.email.split('@').first ?? 'Staff'} 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 13,
                                color: textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Notifications Icon Button
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            tooltip: 'Notifications',
                            style: IconButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? const Color(0xFF1e2d3d)
                                  : const Color(0xFFf1f5f9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const NotificationsScreen()),
                            ),
                            icon: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              size: 22,
                              color: unreadCount > 0
                                  ? primaryColor
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.85,
                                    ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -1,
                              right: -1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFef4444),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: cardBgColor,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFef4444,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                      letterSpacing: -0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Desktop Refresh Button
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Refresh Dashboard',
                          style: IconButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? const Color(0xFF1e2d3d)
                                : const Color(0xFFf1f5f9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            ref.invalidate(eventsStreamProvider);
                            ref.invalidate(ordersStreamProvider);
                            ref.invalidate(notificationsStreamProvider);
                            ref.invalidate(dashboardStripNotifierProvider);
                            ref.invalidate(currentEmployeeProfileProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dashboard refreshed'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // Main Dashboard Body
            Expanded(
              child: ref
                  .watch(eventsStreamProvider)
                  .when(
                    data: (events) {
                      return _buildMainDashboardActions(
                        context,
                        events,
                        myProfile,
                        isDarkMode,
                        primaryColor,
                        cardBgColor,
                        borderColor,
                        textMuted,
                      );
                    },
                    loading: () => _buildShimmerLoading(context),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Dashboard Body with Weekly Strip & Staff Action Module Tiles
  Widget _buildMainDashboardActions(
    BuildContext context,
    List<EventEntity> events,
    EmployeeProfileEntity? myProfile,
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(authNotifierProvider).user;
    final currentUserId = currentUser?.uid;
    final currentUserEmail = currentUser?.email.toLowerCase();

    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final allItems = ref.watch(allItemsStreamProvider).value ?? [];
    final orderMap = {for (final o in orders) o.id: o};

    // Filter manual tasks assigned to this staff member
    final myManualTasks = allItems.where((i) {
      if (!i.isManualTask) return false;
      if (currentUserId != null && i.assignedStaffId == currentUserId) return true;
      if (currentUserEmail != null &&
          i.assignedStaffId != null &&
          i.assignedStaffId!.toLowerCase().trim() == currentUserEmail) {
        return true;
      }
      if (currentUserEmail != null &&
          i.assignedStaffName != null &&
          (i.assignedStaffName!.toLowerCase().contains(currentUserEmail) ||
              currentUserEmail.contains(i.assignedStaffName!.toLowerCase()))) {
        return true;
      }
      if (i.assignedStaffId == null || i.assignedStaffId!.isEmpty) return true;
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return 0;
      });
    final pendingManualTasks =
        myManualTasks.where((t) => !t.isCompleted).length;

    // Dynamically resolve event details from parent order to guarantee real-time synchronization
    final resolvedEvents = events.map((e) {
      final linkedOrder = orderMap[e.orderId];
      if (linkedOrder != null) {
        return e.copyWith(
          date: linkedOrder.eventDate,
          title: linkedOrder.eventName.isNotEmpty
              ? linkedOrder.eventName
              : e.title,
          location: linkedOrder.venue.isNotEmpty
              ? linkedOrder.venue
              : e.location,
          isArchived: linkedOrder.isArchived,
        );
      }
      return e;
    }).toList();

    // Filter assigned events for this staff member
    final userAssignedEvents = resolvedEvents.where((e) {
      if (e.status == 'Draft' || e.isArchived) return false;

      // 1. Direct assignment on Event
      if (e.assignedStaffId != null &&
          e.assignedStaffId!.isNotEmpty &&
          (e.assignedStaffId == currentUserId ||
              (currentUserEmail != null &&
                  e.assignedStaffId?.toLowerCase() == currentUserEmail))) {
        return true;
      }

      // 2. Assignment via Order
      final matchingOrder = orders.where((o) => o.id == e.orderId).firstOrNull;
      if (matchingOrder != null && matchingOrder.assignedStaffIds.isNotEmpty) {
        if (matchingOrder.assignedStaffIds.contains(currentUserId) ||
            (currentUserEmail != null &&
                matchingOrder.assignedStaffIds.any(
                  (id) => id.toLowerCase() == currentUserEmail,
                ))) {
          return true;
        }
      }

      // 3. Assignment via Order Items / Tasks
      final orderItems = allItems.where((i) => i.orderId == e.orderId);
      if (orderItems.any(
        (i) =>
            (i.assignedStaffId != null && i.assignedStaffId == currentUserId) ||
            (i.assignedStaffName != null &&
                currentUserEmail != null &&
                i.assignedStaffName!.toLowerCase().contains(currentUserEmail)),
      )) {
        return true;
      }

      return false;
    }).toList();

    final hasAnyAssignmentsInDb =
        resolvedEvents.any(
          (e) => e.assignedStaffId != null && e.assignedStaffId!.isNotEmpty,
        ) ||
        orders.any((o) => o.assignedStaffIds.isNotEmpty) ||
        allItems.any(
          (i) => i.assignedStaffId != null && i.assignedStaffId!.isNotEmpty,
        );

    final assignedEvents =
        (userAssignedEvents.isEmpty && !hasAnyAssignmentsInDb)
        ? resolvedEvents
              .where((e) => e.status != 'Draft' && !e.isArchived)
              .toList()
        : userAssignedEvents;

    assignedEvents.sort((a, b) => a.date.compareTo(b.date));

    final activeEvents = assignedEvents
        .where((e) => e.status == 'In Progress')
        .length;
    final completedEvents = assignedEvents
        .where((e) => e.status == 'Completed')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;

        int gridCrossAxisCount;
        double childAspectRatio;

        if (width >= 1200) {
          gridCrossAxisCount = 4;
          childAspectRatio = 1.15;
        } else if (width >= 900) {
          gridCrossAxisCount = 4;
          childAspectRatio = 1.15;
        } else if (width >= 600) {
          gridCrossAxisCount = 3;
          childAspectRatio = 1.05;
        } else {
          gridCrossAxisCount = 2;
          childAspectRatio = 0.98;
        }

        final hPadding = isMobile ? 16.0 : 24.0;
        final vPadding = isMobile ? 14.0 : 20.0;
        final gridSpacing = isMobile ? 12.0 : 18.0;

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            ref.invalidate(eventsStreamProvider);
            ref.invalidate(ordersStreamProvider);
            ref.invalidate(notificationsStreamProvider);
            ref.invalidate(dashboardStripNotifierProvider);
            ref.invalidate(currentEmployeeProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: hPadding,
              vertical: vPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Profile Incomplete Alert Banner
                if (!_isProfileComplete(myProfile)) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFf59e0b,
                      ).withValues(alpha: isDarkMode ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFf59e0b).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFf59e0b,
                            ).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_ind_rounded,
                            color: Color(0xFFf59e0b),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile & KYC Incomplete',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFf59e0b),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Please complete your personal and identity details for official records.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              SlidePageRoute(
                                page: AddEmployeeScreen(
                                  userId: currentUser!.uid,
                                  userName: myProfile?.name.isNotEmpty == true
                                      ? myProfile!.name
                                      : (currentUser.email.isNotEmpty
                                            ? currentUser.email.split('@').first
                                            : 'Staff'),
                                  userEmail: currentUser.email,
                                  userRole: UserRole.staff,
                                  isStaffSelfEdit: true,
                                  initialProfile: myProfile,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFf59e0b),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Complete Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Weekly Events Strip at the Top
                ThisWeekEventsStrip(events: events),
                const SizedBox(height: 20),

                // 2. Section Title
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Staff Workspace Modules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Manrope',
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Grid of Staff Action Module Tiles
                GridView.count(
                  crossAxisCount: gridCrossAxisCount,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: childAspectRatio,
                  children: [
                    // 1. My Tasks & Operations
                    _buildModuleCard(
                      title: 'My Tasks & Ops',
                      subtitle: pendingManualTasks > 0
                          ? '$pendingManualTasks pending task${pendingManualTasks > 1 ? "s" : ""}'
                          : 'Assigned checklist & tasks',
                      icon: Icons.task_alt_rounded,
                      accentColor: const Color(0xFF0075db), // Blue
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isProminent: true,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const TasksScreen()),
                      ),
                    ),

                    // 2. Attendance & Check-In
                    _buildModuleCard(
                      title: 'Attendance',
                      subtitle: 'Daily check-in & geofence',
                      icon: Icons.access_time_rounded,
                      accentColor: const Color(0xFF10b981), // Emerald Green
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isProminent: true,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const StaffAttendanceScreen()),
                      ),
                    ),

                    // 3. Request Leave
                    _buildModuleCard(
                      title: 'Request Leave',
                      subtitle: 'Apply for time-off & leaves',
                      icon: Icons.time_to_leave_rounded,
                      accentColor: const Color(0xFFf59e0b), // Amber
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isMobile: isMobile,
                      onTap: () => showStaffLeaveRequestSheet(context, ref),
                    ),

                    // 4. Calendar & Schedule
                    _buildModuleCard(
                      title: 'Calendar & Schedule',
                      subtitle: 'Event schedule & timeline',
                      icon: Icons.calendar_month_rounded,
                      accentColor: const Color(0xFF6366f1), // Indigo
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const CalendarScreen()),
                      ),
                    ),

                    // 5. Company PDF & Assets
                    _buildModuleCard(
                      title: 'Company Profile',
                      subtitle: 'Synology documents & assets',
                      icon: Icons.picture_as_pdf_rounded,
                      accentColor: const Color(0xFFe11d48), // Rose
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                      ),
                    ),

                    // 6. Notifications
                    _buildModuleCard(
                      title: 'Notifications',
                      subtitle: 'Live alerts & work updates',
                      icon: Icons.notifications_active_rounded,
                      accentColor: const Color(0xFFa855f7), // Purple
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const NotificationsScreen()),
                      ),
                    ),

                    // 7. My Profile & Account
                    _buildModuleCard(
                      title: 'My Profile',
                      subtitle: 'Staff credentials & info',
                      icon: Icons.person_pin_rounded,
                      accentColor: const Color(0xFF64748b), // Slate
                      cardBgColor: cardBgColor,
                      borderColor: borderColor,
                      textMuted: textMuted,
                      isMobile: isMobile,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const StaffProfileScreen()),
                      ),
                    ),
                  ],
                ),

                // ── Direct Tasks from Admin (if any) ───────────────────────
                if (myManualTasks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFf97316),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Direct Tasks from Admin (${myManualTasks.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Manrope',
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          SlidePageRoute(page: const TasksScreen()),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFf97316),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: myManualTasks.length > 3 ? 3 : myManualTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final task = myManualTasks[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: task.isCompleted
                                ? borderColor
                                : const Color(0xFFf97316).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => ref
                                  .read(orderItemNotifierProvider.notifier)
                                  .toggleCompletion(task),
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: task.isCompleted
                                      ? Colors.green
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: task.isCompleted
                                        ? Colors.green
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: task.isCompleted
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.itemName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted ? textMuted : null,
                                    ),
                                  ),
                                  if (task.specification.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      task.specification,
                                      style: TextStyle(
                                          fontSize: 12, color: textMuted),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (task.isCompleted
                                        ? Colors.green
                                        : const Color(0xFFf97316))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                task.isCompleted ? 'Done' : 'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: task.isCompleted
                                      ? Colors.green
                                      : const Color(0xFFf97316),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 28),

                // 4. Ongoing Assigned Events Header & Cards
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'My Assigned Events (${assignedEvents.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Manrope',
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    // Quick active / done summary pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '$activeEvents Active • $completedEvents Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (assignedEvents.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active assigned events right now',
                          style: TextStyle(
                            fontSize: 15,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: assignedEvents.length,
                    itemBuilder: (context, index) {
                      final event = assignedEvents[index];
                      final orderItems = allItems
                          .where((i) => i.orderId == event.orderId)
                          .toList();
                      final total = orderItems.length;
                      final completed = orderItems
                          .where((i) => i.isCompleted)
                          .length;
                      final completion = total > 0 ? completed / total : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildEventCard(
                          event: event,
                          calculatedCompletion: completion,
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          colorScheme: colorScheme,
                          textMuted: textMuted,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Easy Clickable Centered Module Card
  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color cardBgColor,
    required Color borderColor,
    required Color textMuted,
    required VoidCallback onTap,
    bool isProminent = false,
    bool isMobile = false,
  }) {
    final cardPaddingHorizontal = isMobile ? 10.0 : 16.0;
    final cardPaddingVertical = isMobile ? 12.0 : 20.0;
    final iconPadding = isMobile ? 10.0 : 16.0;
    final iconSize = isMobile ? 28.0 : 40.0;
    final spacingHeight = isMobile ? 8.0 : 14.0;
    final titleFontSize = isMobile ? 13.5 : 17.0;
    final subtitleFontSize = isMobile ? 10.5 : 12.0;

    return Material(
      color: isProminent ? accentColor.withValues(alpha: 0.05) : cardBgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: cardPaddingHorizontal,
            vertical: cardPaddingVertical,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isProminent
                  ? accentColor.withValues(alpha: 0.45)
                  : borderColor,
              width: isProminent ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: iconSize),
              ),
              SizedBox(height: spacingHeight),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required EventEntity event,
    required double calculatedCompletion,
    required Color cardBgColor,
    required Color borderColor,
    required ColorScheme colorScheme,
    required Color textMuted,
  }) {
    final statusColor = event.status == 'In Progress'
        ? colorScheme.primary
        : (event.status == 'Completed'
              ? const Color(0xFF10b981)
              : const Color(0xFFf59e0b));

    final dateStr = formatNepaliDate(event.date, 'MMM dd, yyyy');
    final completionText = '${(calculatedCompletion * 100).toInt()}% Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  event.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today, color: textMuted, size: 16),
              const SizedBox(width: 8),
              Text(dateStr, style: TextStyle(fontSize: 13, color: textMuted)),
              const SizedBox(width: 20),
              Icon(Icons.location_on, color: textMuted, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  style: TextStyle(fontSize: 13, color: textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              Text(
                completionText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: calculatedCompletion.clamp(0.0, 1.0),
              backgroundColor: borderColor,
              color: statusColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: EventTaskDetailScreen(event: event)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Tasks & Checklists',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => const OrderCardShimmer(),
      ),
    );
  }
}
