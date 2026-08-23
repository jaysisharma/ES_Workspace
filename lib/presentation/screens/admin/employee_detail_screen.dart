import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/core/services/employee_pdf_service.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/user_providers.dart';
import 'package:order_app/core/services/admin_auth_service.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/presentation/screens/admin/add_employee_screen.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final UserEntity user;
  final EmployeeProfileEntity? initialProfile;

  const EmployeeDetailScreen({
    super.key,
    required this.user,
    this.initialProfile,
  });

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  Future<void> _printEmployeePdf(EmployeeProfileEntity profile, {bool share = false}) async {
    try {
      final pdfData = await EmployeePdfService.generateEmployeeDetailPdf(
        profile: profile,
        user: widget.user,
      );

      final fileName = 'Employee_Profile_${profile.name.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (!mounted) return;

      if (share) {
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfData,
          fileName: fileName,
          subject: 'Employee Profile - ${profile.name}',
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: pdfData,
              title: 'Employee Profile - ${profile.name}',
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate Employee PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteEmployee(BuildContext context, EmployeeProfileEntity profile) async {
    bool deleteUserAccount = true;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Delete Employee Record',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete "${profile.name}" from employee records?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '⚠️ This will permanently remove their HR profile, payroll data, documents, and credentials.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: deleteUserAccount,
                activeColor: Colors.red,
                title: Text(
                  'Also remove user login (${widget.user.email})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    deleteUserAccount = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await ref
            .read(employeeProfileNotifierProvider.notifier)
            .deleteProfileByUserId(widget.user.id);

        if (deleteUserAccount) {
          await ref
              .read(userNotifierProvider.notifier)
              .deleteUser(widget.user.id);
        }

        ref.invalidate(usersStreamProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee "${profile.name}" deleted successfully.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete employee: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showChangeCredentialsDialog(
    BuildContext context,
    EmployeeProfileEntity profile,
    UserEntity currentUser,
  ) async {
    final emailController = TextEditingController(text: currentUser.email);
    final passwordController = TextEditingController();
    UserRole selectedRole = currentUser.role;
    bool isSaving = false;
    bool obscurePassword = true;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF0075db)),
              SizedBox(width: 8),
              Text('Account & Access Role',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin can update the login email, change password, and reassign system access roles directly.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Login Email Address',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password (Optional / Min 6 chars)',
                    hintText: 'Leave blank to keep current password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'System Access Role',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: selectedRole,
                      isExpanded: true,
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                role == UserRole.admin
                                    ? Icons.admin_panel_settings
                                    : role == UserRole.founder
                                    ? Icons.stars
                                    : role == UserRole.finance
                                    ? Icons.account_balance
                                    : Icons.badge_outlined,
                                size: 18,
                                color: role == UserRole.admin
                                    ? Colors.purple
                                    : role == UserRole.founder
                                    ? Colors.blue
                                    : role == UserRole.finance
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(role.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newRole) {
                        if (newRole != null) {
                          setDialogState(() => selectedRole = newRole);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0075db),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newEmail = emailController.text.trim();
                      final newPassword = passwordController.text.trim();

                      if (newPassword.isNotEmpty && newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Password must be at least 6 characters.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await AdminAuthService.updateEmployeeCredentials(
                          userId: currentUser.id,
                          oldEmail: currentUser.email,
                          newEmail: newEmail,
                          newPassword: newPassword.isNotEmpty ? newPassword : null,
                          role: selectedRole,
                          name: profile.name,
                          profileId: profile.id,
                        );

                        ref.invalidate(usersStreamProvider);
                        ref.invalidate(employeeProfilesStreamProvider);

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Account details and role updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error updating account: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline.withValues(alpha: 0.2);

    final usersStream = ref.watch(usersStreamProvider);
    final currentUser = usersStream.maybeWhen(
      data: (users) =>
          users
              .where(
                (u) =>
                    u.id == widget.user.id ||
                    (widget.user.email.isNotEmpty &&
                        u.email.toLowerCase() ==
                            widget.user.email.toLowerCase()),
              )
              .firstOrNull ??
          widget.user,
      orElse: () => widget.user,
    );

    final profilesStream = ref.watch(employeeProfilesStreamProvider);

    final profile = profilesStream.maybeWhen(
      data: (list) => list.cast<EmployeeProfileEntity>().firstWhere(
        (p) => p.userId == widget.user.id || (currentUser.id.isNotEmpty && p.userId == currentUser.id),
        orElse: () => widget.initialProfile ?? _createDefaultProfile(),
      ),
      orElse: () => widget.initialProfile ?? _createDefaultProfile(),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Employee Profile: ${profile.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: colorScheme.primary),
            tooltip: 'Print / Preview PDF',
            onPressed: () => _printEmployeePdf(profile, share: false),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Employee PDF',
            onPressed: () => _printEmployeePdf(profile, share: true),
          ),
          IconButton(
            icon: const Icon(Icons.lock_reset, color: Color(0xFF0075db)),
            tooltip: 'Change Password & Role',
            onPressed: () => _showChangeCredentialsDialog(context, profile, currentUser),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit HR Profile',
            onPressed: () {
              context.pushPage(AddEmployeeScreen(
                  userId: currentUser.id,
                  userName: currentUser.name,
                  userEmail: currentUser.email,
                  userRole: currentUser.role,
                  initialProfile: profile));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Delete Employee Record',
            onPressed: () => _confirmDeleteEmployee(context, profile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Header Profile Card
            _buildProfileHeaderCard(context, profile, currentUser, isDarkMode),
            const SizedBox(height: 16),

            // 2. Office & Salary Breakdown Card
            _buildPayrollTab(context, profile, borderColor, labelColor, textColor),
            const SizedBox(height: 16),

            // 3. Personal & Family Information Card
            _buildPersonalTab(context, profile, currentUser, borderColor, labelColor, textColor),
            const SizedBox(height: 16),

            // 4. Leave Allocations Card
            _buildLeaveAllocationsTab(context, profile, borderColor, labelColor, textColor),
            const SizedBox(height: 16),

            // 5. Credentials & Identification Documents Grid
            _buildDocumentsTab(context, profile, borderColor, labelColor, textColor),
            const SizedBox(height: 20),

            // 6. Action Bar for PDF Generation
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('PREVIEW / PRINT PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _printEmployeePdf(profile, share: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('SHARE DOSSIER PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _printEmployeePdf(profile, share: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  EmployeeProfileEntity _createDefaultProfile() {
    return EmployeeProfileEntity(
      id: widget.user.id,
      userId: widget.user.id,
      name: widget.user.name,
      designation: 'Event Specialist',
      officeJoinDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Widget _buildProfileHeaderCard(
      BuildContext context, EmployeeProfileEntity profile, UserEntity currentUser, bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 80,
                height: 80,
                color: colorScheme.primaryContainer,
                child: (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                    ? _renderDocumentImage(profile.photoUrl!, colorScheme)
                    : Center(
                        child: Text(
                          profile.name.isNotEmpty
                              ? profile.name[0].toUpperCase()
                              : 'E',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Blood: ${profile.bloodGroup}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currentUser.role.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.designation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (currentUser.email.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined,
                                size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              currentUser.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Joined: ${formatNepaliDate(profile.officeJoinDate, 'dd MMM yyyy')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Personal & Family Info
  Widget _buildPersonalTab(
    BuildContext context,
    EmployeeProfileEntity profile,
    UserEntity currentUser,
    Color borderColor,
    Color labelColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Personal & Account Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              _buildDetailRow('Full Name', profile.name, labelColor, textColor),
              _buildDetailRow(
                  'Login Email Address',
                  currentUser.email.isNotEmpty ? currentUser.email : 'N/A',
                  labelColor,
                  textColor),
              _buildDetailRow('System Access Role', currentUser.role.displayName,
                  labelColor, textColor),
              _buildDetailRow(
                  'Date of Birth',
                  profile.dob != null
                      ? formatNepaliDate(profile.dob!, 'dd MMM yyyy')
                      : 'N/A',
                  labelColor,
                  textColor),
              _buildDetailRow('Blood Group', profile.bloodGroup, labelColor, textColor),
              _buildDetailRow(
                  'Permanent Address',
                  profile.address.isNotEmpty ? profile.address : 'N/A',
                  labelColor,
                  textColor),
              const SizedBox(height: 20),
              const Text('Family Background Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              _buildDetailRow(
                  'Father\'s Name',
                  profile.fatherName.isNotEmpty ? profile.fatherName : 'N/A',
                  labelColor,
                  textColor),
              _buildDetailRow(
                  'Mother\'s Name',
                  profile.motherName.isNotEmpty ? profile.motherName : 'N/A',
                  labelColor,
                  textColor),
              _buildDetailRow(
                  'Grandfather\'s Name',
                  profile.grandfatherName.isNotEmpty
                      ? profile.grandfatherName
                      : 'N/A',
                  labelColor,
                  textColor),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: Office & Payroll
  Widget _buildPayrollTab(
    BuildContext context,
    EmployeeProfileEntity profile,
    Color borderColor,
    Color labelColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Employment & Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              _buildDetailRow('Designation', profile.designation, labelColor, textColor),
              _buildDetailRow(
                  'Office Join Date',
                  formatNepaliDate(profile.officeJoinDate, 'dd MMM yyyy'),
                  labelColor,
                  textColor),
              _buildDetailRow(
                  'Office Leaving Date',
                  profile.officeLeavingDate != null
                      ? formatNepaliDate(profile.officeLeavingDate!, 'dd MMM yyyy')
                      : 'Active Employee',
                  labelColor,
                  textColor),
              const SizedBox(height: 20),
              const Text('Monthly Compensation & Salary Structure',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              () {
                final gross = profile.grossSalary;
                final tdsPct = gross > 0 ? (profile.tds / gross * 100) : 0.0;

                return Column(
                  children: [
                    _buildDetailRow(
                        'Basic Salary',
                        CurrencyFormatter.formatWithLabel(profile.basicSalary, 'NPR'),
                        labelColor,
                        textColor),
                    if (profile.fuelAllowance > 0)
                      _buildDetailRow(
                          'Fuel Allowance',
                          CurrencyFormatter.formatWithLabel(profile.fuelAllowance, 'NPR'),
                          labelColor,
                          textColor),
                    if (profile.communicationAllowance > 0)
                      _buildDetailRow(
                          'Communication Allowance',
                          CurrencyFormatter.formatWithLabel(profile.communicationAllowance, 'NPR'),
                          labelColor,
                          textColor),
                    if (profile.dearnessAllowance > 0)
                      _buildDetailRow(
                          'Dearness Allowance (DA)',
                          CurrencyFormatter.formatWithLabel(profile.dearnessAllowance, 'NPR'),
                          labelColor,
                          textColor),
                    if (profile.bonus > 0)
                      _buildDetailRow(
                          'Bonus / Allowances',
                          CurrencyFormatter.formatWithLabel(profile.bonus, 'NPR'),
                          labelColor,
                          textColor),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Salary',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            CurrencyFormatter.formatWithLabel(profile.grossSalary, 'NPR'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                        'SSF Contribution',
                        CurrencyFormatter.formatWithLabel(profile.ssf, 'NPR'),
                        labelColor,
                        textColor),
                    if (profile.effectiveLifeInsurance > 0)
                      _buildDetailRow(
                          'Life Insurance',
                          CurrencyFormatter.formatWithLabel(profile.effectiveLifeInsurance, 'NPR'),
                          labelColor,
                          textColor),
                    if (profile.effectiveHealthInsurance > 0)
                      _buildDetailRow(
                          'Health Insurance',
                          CurrencyFormatter.formatWithLabel(profile.effectiveHealthInsurance, 'NPR'),
                          labelColor,
                          textColor),
                    if (profile.cit > 0)
                      _buildDetailRow(
                          'CIT Contribution',
                          CurrencyFormatter.formatWithLabel(profile.cit, 'NPR'),
                          labelColor,
                          textColor),
                    _buildDetailRow(
                        'TDS (Tax Deducted at Source)',
                        '${CurrencyFormatter.formatWithLabel(profile.tds, 'NPR')}${tdsPct > 0 ? ' (${tdsPct.toStringAsFixed(1)}%)' : ''}',
                        labelColor,
                        textColor),
                  ],
                );
              }(),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Net Payable Monthly Salary (In Hand)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatWithLabel(profile.netSalary, 'NPR'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 3: Credentials & Documents
  Widget _buildDocumentsTab(
    BuildContext context,
    EmployeeProfileEntity profile,
    Color borderColor,
    Color labelColor,
    Color textColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDocumentCard(
            context,
            title: 'Citizenship Card',
            cardNumber: profile.citizenshipNumber,
            photoUrl1: profile.citizenshipPhotoFrontUrl,
            photoUrl1Title: 'Citizenship Front',
            photoUrl2: profile.citizenshipPhotoBackUrl,
            photoUrl2Title: 'Citizenship Back',
            borderColor: borderColor,
            labelColor: labelColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildDocumentCard(
            context,
            title: 'NIN Card (National ID)',
            cardNumber: profile.ninNumber,
            photoUrl1: profile.ninPhotoUrl,
            photoUrl1Title: 'NIN Card Photo',
            borderColor: borderColor,
            labelColor: labelColor,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildDocumentCard(
            context,
            title: 'PAN Card',
            cardNumber: profile.panNumber,
            photoUrl1: profile.panPhotoUrl,
            photoUrl1Title: 'PAN Card Photo',
            borderColor: borderColor,
            labelColor: labelColor,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required String title,
    required String cardNumber,
    String? photoUrl1,
    String? photoUrl1Title,
    String? photoUrl2,
    String? photoUrl2Title,
    required Color borderColor,
    required Color labelColor,
    required Color textColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cardNumber.isNotEmpty ? 'No: $cardNumber' : 'Not Uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cardNumber.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            if (photoUrl1 != null || photoUrl2 != null) const SizedBox(height: 12),
            Row(
              children: [
                if (photoUrl1 != null && photoUrl1.isNotEmpty)
                  Expanded(
                    child: _buildPhotoPreview(
                        context, photoUrl1, photoUrl1Title ?? 'Front'),
                  ),
                if (photoUrl1 != null && photoUrl2 != null)
                  const SizedBox(width: 12),
                if (photoUrl2 != null && photoUrl2.isNotEmpty)
                  Expanded(
                    child: _buildPhotoPreview(
                        context, photoUrl2, photoUrl2Title ?? 'Back'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(
      BuildContext context, String photoUrl, String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showFullScreenImage(context, photoUrl, title),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _renderDocumentImage(photoUrl, colorScheme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderDocumentImage(String photoUrl, ColorScheme colorScheme) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Data = photoUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(bytes, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
      } catch (_) {}
    } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return Image.network(photoUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
    } else {
      final file = File(photoUrl);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(photoUrl,
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String photoUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 500, maxWidth: 600),
              padding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                child: _renderDocumentImage(photoUrl, Theme.of(context).colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String title, String value, Color labelColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveAllocationsTab(
    BuildContext context,
    EmployeeProfileEntity profile,
    Color borderColor,
    Color labelColor,
    Color textColor,
  ) {
    final settings = ref.watch(settingsProvider);
    final cycleLabel = NepaliCalendarEngine.getLeaveCycleLabel(
      cycleType: settings.leaveResetCycle,
      manualStartDate: settings.customLeaveCycleStartDate,
    );
    final leaveRequestsAsync = ref.watch(leaveRequestsStreamProvider);
    final leaveRequests = leaveRequestsAsync.maybeWhen(
      data: (list) => list
          .where((l) =>
              l.staffId == widget.user.id &&
              l.status == LeaveStatus.approved &&
              NepaliCalendarEngine.isWithinActiveLeaveCycle(
                l.startDate,
                cycleType: settings.leaveResetCycle,
                manualStartDate: settings.customLeaveCycleStartDate,
              ))
          .toList(),
      orElse: () => <LeaveRequestEntity>[],
    );

    int takenDays(String leaveType) {
      return leaveRequests
          .where((l) => l.leaveType == leaveType)
          .map((l) => l.endDate.difference(l.startDate).inDays + 1)
          .fold(0, (total, days) => total + days);
    }

    final effectiveAllocations = profile.effectiveAllowedLeaves;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event_repeat, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Annual Leave Entitlements ($cycleLabel)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 3.5 : 2.5,
                ),
                itemCount: effectiveAllocations.length,
                itemBuilder: (context, index) {
                  final leaveType = effectiveAllocations.keys.elementAt(index);
                  final allowed = effectiveAllocations[leaveType] ?? 0;
                  final taken = takenDays(leaveType);
                  final remaining = (allowed - taken).clamp(0, allowed);
                  final percent = allowed > 0 ? (taken / allowed).clamp(0.0, 1.0) : 0.0;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Text(
                              '$taken / $allowed Days',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: percent > 0.8 ? Colors.red : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            backgroundColor: borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percent > 0.8 ? Colors.red : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remaining: $remaining days',
                          style: TextStyle(fontSize: 11, color: labelColor),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
