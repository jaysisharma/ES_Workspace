import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/employee_pdf_service.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';
import 'package:order_app/presentation/screens/admin/add_employee_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
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
      final uid = firebaseUser.uid;
      final email = firebaseUser.email ?? '';
      final name = email.isNotEmpty ? email.split('@').first : 'Staff';

      final userEntity = UserEntity(
        id: uid,
        name: name,
        email: email,
        role: UserRole.staff,
        isActive: true,
      );

      final profiles = await ref.read(employeeProfilesStreamProvider.future);
      final profile = profiles.cast<EmployeeProfileEntity>().firstWhere(
        (p) => p.userId == uid,
        orElse: () => EmployeeProfileEntity(
          id: uid,
          userId: uid,
          name: name,
          officeJoinDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
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
        Navigator.of(context).pushAndRemoveUntil(
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
    final settings = ref.watch(settingsProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final profilesAsync = ref.watch(employeeProfilesStreamProvider);

    // Design tokens
    final primaryColor = const Color(0xFF0075db);
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
    final successColor = const Color(0xFF10b981);

    // Derive user info
    final user = authState.user;
    final userEmail = user?.email ?? 'staff@eventflow.app';
    final userId = user?.uid ?? '';
    final rawDisplayName = userEmail.split('@').first;

    final myProfile = profilesAsync.maybeWhen(
      data: (profiles) => profiles.cast<EmployeeProfileEntity?>().firstWhere(
        (p) => p != null && (p.userId == userId || (userEmail.isNotEmpty && p.name.toLowerCase() == rawDisplayName.toLowerCase())),
        orElse: () => null,
      ),
      orElse: () => null,
    );

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
                    ElevatedButton.icon(
                      onPressed: () => _openEditProfile(
                        context,
                        myProfile,
                        userId,
                        displayName,
                        userEmail,
                      ),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Edit Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Profile Card ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Avatar + Edit Button
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (myProfile?.bloodGroup.isNotEmpty == true && myProfile!.bloodGroup != 'N/A') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                              '🩸 ${myProfile.bloodGroup}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Stats Row ────────────────────────────────────────────
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

              // ── Personal & KYC Details Section ────────────────────────
              _SectionHeader(label: 'Personal Information & KYC', labelColor: labelColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Full Name', displayName, textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Designation', myProfile?.designation ?? 'Staff Member', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow(
                      'Date of Birth',
                      myProfile?.dob != null
                          ? formatNepaliDate(myProfile!.dob!, 'dd MMM yyyy (BS)')
                          : 'Not provided',
                      textColor,
                      labelColor,
                    ),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Blood Group', myProfile?.bloodGroup ?? 'N/A', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Address', myProfile?.address.isNotEmpty == true ? myProfile!.address : 'Not provided', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Father\'s Name', myProfile?.fatherName.isNotEmpty == true ? myProfile!.fatherName : 'Not provided', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Mother\'s Name', myProfile?.motherName.isNotEmpty == true ? myProfile!.motherName : 'Not provided', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('Citizenship Number', myProfile?.citizenshipNumber.isNotEmpty == true ? myProfile!.citizenshipNumber : 'Not provided', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('PAN Number', myProfile?.panNumber.isNotEmpty == true ? myProfile!.panNumber : 'Not provided', textColor, labelColor),
                    Divider(height: 20, color: borderColor),
                    _buildInfoRow('National ID (NIN)', myProfile?.ninNumber.isNotEmpty == true ? myProfile!.ninNumber : 'Not provided', textColor, labelColor),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Update Personal & KYC Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _openEditProfile(
                          context,
                          myProfile,
                          userId,
                          displayName,
                          userEmail,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Work & Leave Section ─────────────────────────────────────
              _SectionHeader(label: 'Work & Leave', labelColor: labelColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.time_to_leave_rounded,
                      iconColor: const Color(0xFF10b981),
                      title: 'Apply for Leave / Off-Duty',
                      borderColor: borderColor,
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      onTap: () => showStaffLeaveRequestSheet(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.picture_as_pdf_outlined,
                      iconColor: primaryColor,
                      title: 'Print / Download My Profile PDF',
                      borderColor: borderColor,
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      onTap: () => _printMyEmployeePdf(context, user),
                    ),
                    _SettingsTile(
                      icon: Icons.business_outlined,
                      iconColor: const Color(0xFF8b5cf6),
                      title: 'Company Profile & Share (Synology)',
                      subtitle: 'Generate, preview & share company profile PDF',
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

              // ── Appearance & Notifications ───────────────────────────
              _SectionHeader(label: 'Preferences', labelColor: labelColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: const Color(0xFF818cf8),
                      title: 'Dark Mode',
                      borderColor: borderColor,
                      trailing: Switch.adaptive(
                        value: settings.themeMode == ThemeMode.dark,
                        activeTrackColor: primaryColor,
                        onChanged: (val) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(
                                val ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: const Color(0xFFf59e0b),
                      title: 'Push Notifications',
                      subtitle: 'Alerts for tasks, assignments and announcements',
                      borderColor: borderColor,
                      isLast: true,
                      trailing: Switch.adaptive(
                        value: settings.notificationsEnabled,
                        activeTrackColor: primaryColor,
                        onChanged: (val) {
                          ref
                              .read(settingsProvider.notifier)
                              .toggleNotifications(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Account & Credentials Section ───────────────────────
              _SectionHeader(label: 'Account & Security', labelColor: labelColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
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
                      icon: Icons.security_rounded,
                      iconColor: const Color(0xFF10b981),
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
                      subtitle: 'EventFlow Pro v1.0.0',
                      borderColor: borderColor,
                      isLast: true,
                    ),
                  ],
                ),
              ),

              // ── Sign Out Button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoggingOut ? null : _confirmLogout,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
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

              // ── User ID Info ────────────────────────────────────────
              if (userId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, size: 13, color: labelColor),
                      const SizedBox(width: 4),
                      Text(
                        'ID: ${userId.substring(0, userId.length > 8 ? 8 : userId.length)}…',
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

  Widget _buildInfoRow(String label, String value, Color textColor, Color labelColor) {
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

// ── Helper Widgets ────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
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
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
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
                            color: labelColor,
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
