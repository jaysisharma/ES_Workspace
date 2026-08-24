import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/employee_pdf_service.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';
import 'package:order_app/presentation/widgets/hr_management/staff_leave_balance_card.dart';
import 'package:order_app/presentation/screens/admin/add_employee_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/widgets/common/role_based_router.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  bool _isLoggingOut = false;

  void _openEditProfile(
    BuildContext context,
    EmployeeProfileEntity? profile,
    String uid,
    String name,
    String email,
  ) {
    Navigator.push(
      context,
      SlidePageRoute(
        page: AddEmployeeScreen(
          userId: uid,
          userName: profile?.name.isNotEmpty == true ? profile!.name : name,
          userEmail: email,
          userRole: UserRole.staff,
          isStaffSelfEdit: true,
          initialProfile: profile,
        ),
      ),
    );
  }

  Future<void> _printMyEmployeePdf(BuildContext context, dynamic firebaseUser) async {
    if (firebaseUser == null) return;
    try {
      final myProfile = ref.read(currentEmployeeProfileProvider);
      final email = firebaseUser.email ?? (myProfile?.email.isNotEmpty == true ? myProfile!.email : '');
      final name = myProfile?.name.isNotEmpty == true ? myProfile!.name : (email.isNotEmpty ? email.split('@').first : 'Staff');
      final uid = myProfile?.userId.isNotEmpty == true ? myProfile!.userId : (firebaseUser.uid as String);

      final userEntity = UserEntity(
        id: uid,
        name: name,
        email: email,
        role: UserRole.staff,
        isActive: true,
      );

      final profile = myProfile ?? EmployeeProfileEntity(
        id: uid,
        userId: uid,
        name: name,
        email: email,
        officeJoinDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfData = await EmployeePdfService.generateEmployeeDetailPdf(
        profile: profile,
        user: userEntity,
      );

      final fileName = 'Employee_Profile_${name.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            title: 'My Employee Profile',
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate profile PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1b2631) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoggingOut = true);
      await ref.read(authNotifierProvider.notifier).logout();
      if (mounted) {
        setState(() => _isLoggingOut = false);
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildAvatar(String? photoUrl, String initials, Color primaryColor, Color cardColor) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            photoUrl,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(initials, primaryColor),
          ),
        );
      } else if (photoUrl.startsWith('data:image')) {
        try {
          final base64Data = photoUrl.split(',').last;
          final bytes = base64Decode(base64Data);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      } else {
        final file = File(photoUrl);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        }
      }
    }
    return _buildInitialsAvatar(initials, primaryColor);
  }

  Widget _buildInitialsAvatar(String initials, Color primaryColor) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);

    // Design tokens
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0f1a23)
        : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    const successColor = Color(0xFF10b981);

    // Derive user info
    final user = authState.user;
    final userEmail = user?.email ?? 'staff@eventflow.app';
    final userId = user?.uid ?? '';
    final rawDisplayName = userEmail.split('@').first;

    final myProfile = ref.watch(currentEmployeeProfileProvider);

    final displayName = myProfile?.name.isNotEmpty == true
        ? myProfile!.name
        : (rawDisplayName.isNotEmpty
            ? rawDisplayName.replaceFirst(rawDisplayName[0], rawDisplayName[0].toUpperCase())
            : 'Staff Member');

    final initials = displayName.isNotEmpty
        ? displayName
              .substring(0, displayName.length >= 2 ? 2 : 1)
              .toUpperCase()
        : 'ST';

    // Compute stats from events
    final allEvents = eventsAsync.maybeWhen(
      data: (e) => e,
      orElse: () => <EventEntity>[],
    );
    final assignedEvents = allEvents.where((e) => e.status != 'Draft').toList();
    final activeEvents = assignedEvents
        .where((e) => e.status == 'In Progress' || e.status == 'Pending')
        .length;
    final completedEvents = assignedEvents
        .where((e) => e.status == 'Completed' || e.status == 'Ready')
        .length;
    final avgCompletion = assignedEvents.isEmpty
        ? 0.0
        : assignedEvents.fold(0.0, (sum, e) => sum + e.completion) /
              assignedEvents.length;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context)) ...[
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: textColor),
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                          const SizedBox(width: 4),
                        ],
                        const Text(
                          'My Profile',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditProfile(
                        context,
                        myProfile,
                        userId,
                        displayName,
                        userEmail,
                      ),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Edit Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Profile Hero Card ───────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
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
                  children: [
                    // Avatar + Edit badge
                    GestureDetector(
                      onTap: () => _openEditProfile(
                        context,
                        myProfile,
                        userId,
                        displayName,
                        userEmail,
                      ),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildAvatar(myProfile?.photoUrl, initials, primaryColor, cardColor),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: cardColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            myProfile?.designation.isNotEmpty == true
                                ? myProfile!.designation.toUpperCase()
                                : 'STAFF MEMBER',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        if (myProfile?.bloodGroup.isNotEmpty == true && myProfile!.bloodGroup != 'N/A')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '🩸 ${myProfile!.bloodGroup}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Key Metrics ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Active',
                        value: activeEvents.toString(),
                        icon: Icons.play_circle_outline_rounded,
                        color: primaryColor,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Completed',
                        value: completedEvents.toString(),
                        icon: Icons.check_circle_outline_rounded,
                        color: successColor,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Avg %',
                        value: '${(avgCompletion * 100).toInt()}%',
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFFf59e0b),
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Sub-Pages Navigation Hub ─────────────────────────────
              _SectionHeader(label: 'Account & Services', labelColor: labelColor),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFF0075db),
                      title: 'Personal & KYC Details',
                      subtitle: 'Full name, DoB, citizenship, PAN, address, family',
                      borderColor: borderColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: StaffPersonalKycScreen(
                              profile: myProfile,
                              userId: userId,
                              displayName: displayName,
                              userEmail: userEmail,
                            ),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFF10b981),
                      title: 'Leave & Attendance Portal',
                      subtitle: 'Leave balances, submit off-duty, shift records',
                      borderColor: borderColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: const StaffLeaveAttendanceScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.folder_shared_outlined,
                      iconColor: const Color(0xFF8b5cf6),
                      title: 'Documents & PDF Center',
                      subtitle: 'Employee profile PDF & Synology company profile',
                      borderColor: borderColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: StaffDocumentsScreen(user: user),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFFf59e0b),
                      title: 'Preferences & Notifications',
                      subtitle: 'Theme customization, alerts, vibration',
                      borderColor: borderColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: const StaffPreferencesScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF6366f1),
                      title: 'Account & Security',
                      subtitle: 'Login credentials, access role, app details',
                      borderColor: borderColor,
                      isLast: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: StaffAccountSecurityScreen(
                              userEmail: userEmail,
                              userId: userId,
                              designation: myProfile?.designation,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Sign Out Button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _confirmLogout,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : const Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                    label: Text(
                      _isLoggingOut ? 'Signing out…' : 'Sign Out',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // ── User ID Footer ──────────────────────────────────────
              if (userId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, size: 13, color: labelColor),
                      const SizedBox(width: 4),
                      Text(
                        'User ID: ${userId.substring(0, userId.length > 8 ? 8 : userId.length)}…',
                        style: TextStyle(fontSize: 11, color: labelColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 📋 SUB-PAGE 1: Personal & KYC Details Screen
// ═════════════════════════════════════════════════════════════════════════════

class StaffPersonalKycScreen extends ConsumerWidget {
  final EmployeeProfileEntity? profile;
  final String userId;
  final String displayName;
  final String userEmail;

  const StaffPersonalKycScreen({
    super.key,
    required this.profile,
    required this.userId,
    required this.displayName,
    required this.userEmail,
  });

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      SlidePageRoute(
        page: AddEmployeeScreen(
          userId: userId,
          userName: profile?.name.isNotEmpty == true ? profile!.name : displayName,
          userEmail: userEmail,
          userRole: UserRole.staff,
          isStaffSelfEdit: true,
          initialProfile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    // Watch live profile if updated
    final liveProfile = ref.watch(currentEmployeeProfileProvider) ?? profile;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Personal & KYC Details',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: primaryColor),
            tooltip: 'Edit Details',
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Basic Information
            _buildGroupCard(
              cardColor: cardColor,
              borderColor: borderColor,
              title: 'Basic Information',
              icon: Icons.person_outline_rounded,
              iconColor: primaryColor,
              textColor: textColor,
              children: [
                _buildRow('Full Name', liveProfile?.name.isNotEmpty == true ? liveProfile!.name : displayName, textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('Designation', liveProfile?.designation ?? 'Staff Member', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow(
                  'Date of Birth',
                  liveProfile?.dob != null ? formatNepaliDate(liveProfile!.dob!, 'dd MMM yyyy (BS)') : 'Not provided',
                  textColor,
                  labelColor,
                ),
                Divider(height: 20, color: borderColor),
                _buildRow('Blood Group', liveProfile?.bloodGroup ?? 'N/A', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow(
                  'Office Join Date',
                  liveProfile?.officeJoinDate != null ? formatNepaliDate(liveProfile!.officeJoinDate, 'dd MMM yyyy (BS)') : 'Not provided',
                  textColor,
                  labelColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Section 2: Contact & Address
            _buildGroupCard(
              cardColor: cardColor,
              borderColor: borderColor,
              title: 'Contact & Residence',
              icon: Icons.home_outlined,
              iconColor: const Color(0xFF10b981),
              textColor: textColor,
              children: [
                _buildRow('Email Address', userEmail, textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('Residential Address', liveProfile?.address.isNotEmpty == true ? liveProfile!.address : 'Not provided', textColor, labelColor),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Identification & Government KYC
            _buildGroupCard(
              cardColor: cardColor,
              borderColor: borderColor,
              title: 'Government Identification (KYC)',
              icon: Icons.assignment_ind_outlined,
              iconColor: const Color(0xFF8b5cf6),
              textColor: textColor,
              children: [
                _buildRow('Citizenship Number', liveProfile?.citizenshipNumber.isNotEmpty == true ? liveProfile!.citizenshipNumber : 'Not provided', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('PAN Number', liveProfile?.panNumber.isNotEmpty == true ? liveProfile!.panNumber : 'Not provided', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('National ID (NIN)', liveProfile?.ninNumber.isNotEmpty == true ? liveProfile!.ninNumber : 'Not provided', textColor, labelColor),
              ],
            ),
            const SizedBox(height: 16),

            // Section 4: Family Details
            _buildGroupCard(
              cardColor: cardColor,
              borderColor: borderColor,
              title: 'Family Details',
              icon: Icons.family_restroom_outlined,
              iconColor: const Color(0xFFf59e0b),
              textColor: textColor,
              children: [
                _buildRow('Father\'s Name', liveProfile?.fatherName.isNotEmpty == true ? liveProfile!.fatherName : 'Not provided', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('Mother\'s Name', liveProfile?.motherName.isNotEmpty == true ? liveProfile!.motherName : 'Not provided', textColor, labelColor),
                Divider(height: 20, color: borderColor),
                _buildRow('Grandfather\'s Name', liveProfile?.grandfatherName.isNotEmpty == true ? liveProfile!.grandfatherName : 'Not provided', textColor, labelColor),
              ],
            ),
            const SizedBox(height: 24),

            // Edit CTA
            ElevatedButton.icon(
              onPressed: () => _openEdit(context),
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text('Update Profile & KYC Information', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required Color cardColor,
    required Color borderColor,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color textColor, Color labelColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 🌴 SUB-PAGE 2: Leave & Attendance Portal
// ═════════════════════════════════════════════════════════════════════════════

class StaffLeaveAttendanceScreen extends ConsumerWidget {
  const StaffLeaveAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Leave & Attendance Portal',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Leave Balances Overview
            const StaffLeaveBalanceCard(),
            const SizedBox(height: 16),

            // 2. Action Cards
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.time_to_leave_rounded,
                    iconColor: const Color(0xFF10b981),
                    title: 'Apply for Leave / Off-Duty',
                    subtitle: 'Submit a new leave request to Administration',
                    borderColor: borderColor,
                    onTap: () => showStaffLeaveRequestSheet(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.co_present_outlined,
                    iconColor: primaryColor,
                    title: 'My Shift Attendance Records',
                    subtitle: 'View check-in history, clock times, and shift logs',
                    borderColor: borderColor,
                    isLast: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        SlidePageRoute(
                          page: const StaffAttendanceScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Info Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Leave requests must be submitted at least 24 hours in advance. Once reviewed by Management, status updates will be delivered instantly via Notifications.',
                      style: TextStyle(fontSize: 12.5, color: textColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 📄 SUB-PAGE 3: Documents & PDF Center
// ═════════════════════════════════════════════════════════════════════════════

class StaffDocumentsScreen extends ConsumerWidget {
  final dynamic user;

  const StaffDocumentsScreen({super.key, required this.user});

  Future<void> _generateProfilePdf(BuildContext context, WidgetRef ref) async {
    try {
      final myProfile = ref.read(currentEmployeeProfileProvider);
      final email = user?.email ?? (myProfile?.email.isNotEmpty == true ? myProfile!.email : '');
      final name = myProfile?.name.isNotEmpty == true ? myProfile!.name : (email.isNotEmpty ? email.split('@').first : 'Staff');
      final uid = myProfile?.userId.isNotEmpty == true ? myProfile!.userId : (user?.uid ?? '');

      final userEntity = UserEntity(
        id: uid,
        name: name,
        email: email,
        role: UserRole.staff,
        isActive: true,
      );

      final profile = myProfile ?? EmployeeProfileEntity(
        id: uid,
        userId: uid,
        name: name,
        email: email,
        officeJoinDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfData = await EmployeePdfService.generateEmployeeDetailPdf(
        profile: profile,
        user: userEntity,
      );

      final fileName = 'Employee_Profile_${name.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            title: 'My Employee Profile',
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate profile PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Documents & PDF Center',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: primaryColor,
                    title: 'My Employee Profile PDF',
                    subtitle: 'Generate, preview & export your verified staff biodata',
                    borderColor: borderColor,
                    onTap: () => _generateProfilePdf(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.business_outlined,
                    iconColor: const Color(0xFF8b5cf6),
                    title: 'Company Profile & Share (Synology)',
                    subtitle: 'Access and share official company brochures and decks',
                    borderColor: borderColor,
                    isLast: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SynologyCompanyPdfScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ⚙️ SUB-PAGE 4: Preferences & Settings
// ═════════════════════════════════════════════════════════════════════════════

class StaffPreferencesScreen extends ConsumerWidget {
  const StaffPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preferences & Settings',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    iconColor: const Color(0xFF818cf8),
                    title: 'Dark Theme',
                    subtitle: 'Switch between dark and light appearance',
                    borderColor: borderColor,
                    trailing: Switch.adaptive(
                      value: settings.themeMode == ThemeMode.dark,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setThemeMode(
                              val ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    iconColor: const Color(0xFFf59e0b),
                    title: 'Push Notifications',
                    subtitle: 'Receive real-time task alerts and event assignments',
                    borderColor: borderColor,
                    isLast: true,
                    trailing: Switch.adaptive(
                      value: settings.notificationsEnabled,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).toggleNotifications(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 🔒 SUB-PAGE 5: Account & Security Screen
// ═════════════════════════════════════════════════════════════════════════════

class StaffAccountSecurityScreen extends StatelessWidget {
  final String userEmail;
  final String userId;
  final String? designation;

  const StaffAccountSecurityScreen({
    super.key,
    required this.userEmail,
    required this.userId,
    this.designation,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0f1a23) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1b2631) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account & Security',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.email_outlined,
                    iconColor: primaryColor,
                    title: 'Login Email Address',
                    subtitle: userEmail,
                    borderColor: borderColor,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Locked', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF10b981),
                    title: 'System Access Role',
                    subtitle: 'Staff Member (${designation ?? 'Active'})',
                    borderColor: borderColor,
                  ),
                  _SettingsTile(
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFFf59e0b),
                    title: 'Account Password',
                    subtitle: 'Managed securely by Company Administration',
                    borderColor: borderColor,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('Locked', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: primaryColor,
                    title: 'App Version',
                    subtitle: 'EventFlow Pro v1.2.0',
                    borderColor: borderColor,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'To change email or password credentials, contact an administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── Helper Widgets ────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color labelColor;

  const _SectionHeader({required this.label, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: labelColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color borderColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.borderColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(
                            Icons.chevron_right_rounded,
                            color: labelColor.withValues(alpha: 0.6),
                            size: 20,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 56, endIndent: 0, color: borderColor),
      ],
    );
  }
}

