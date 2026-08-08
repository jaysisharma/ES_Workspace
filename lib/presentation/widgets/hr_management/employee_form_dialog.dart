import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';

class EmployeeFormDialog extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final bool isNewUser;
  final EmployeeProfileEntity? initialProfile;

  const EmployeeFormDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.isNewUser = false,
    this.initialProfile,
  });

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _fatherNameController;
  late TextEditingController _motherNameController;
  late TextEditingController _grandfatherNameController;
  late TextEditingController _addressController;
  String _bloodGroup = 'A+';

  DateTime? _dob;
  DateTime _officeJoinDate = DateTime.now();
  DateTime? _officeLeavingDate;

  late TextEditingController _basicSalaryController;
  late TextEditingController _bonusController;
  late TextEditingController _ssfController;
  late TextEditingController _citController;
  late TextEditingController _insuranceController;

  late TextEditingController _photoUrlController;
  late TextEditingController _citizenshipNumberController;
  late TextEditingController _citizenshipFrontController;
  late TextEditingController _citizenshipBackController;
  late TextEditingController _ninNumberController;
  late TextEditingController _ninPhotoController;
  late TextEditingController _panNumberController;
  late TextEditingController _panPhotoController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final p = widget.initialProfile;

    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController(text: p?.name ?? widget.userName);
    _designationController =
        TextEditingController(text: p?.designation ?? 'Event Specialist');
    _fatherNameController = TextEditingController(text: p?.fatherName ?? '');
    _motherNameController = TextEditingController(text: p?.motherName ?? '');
    _grandfatherNameController =
        TextEditingController(text: p?.grandfatherName ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _bloodGroup = p?.bloodGroup.isNotEmpty == true ? p!.bloodGroup : 'A+';

    _dob = p?.dob;
    _officeJoinDate = p?.officeJoinDate ?? DateTime.now();
    _officeLeavingDate = p?.officeLeavingDate;

    _basicSalaryController =
        TextEditingController(text: p?.basicSalary.toString() ?? '0');
    _bonusController = TextEditingController(text: p?.bonus.toString() ?? '0');
    _ssfController = TextEditingController(text: p?.ssf.toString() ?? '0');
    _citController = TextEditingController(text: p?.cit.toString() ?? '0');
    _insuranceController =
        TextEditingController(text: p?.insurance.toString() ?? '0');

    _photoUrlController = TextEditingController(text: p?.photoUrl ?? '');
    _citizenshipNumberController =
        TextEditingController(text: p?.citizenshipNumber ?? '');
    _citizenshipFrontController =
        TextEditingController(text: p?.citizenshipPhotoFrontUrl ?? '');
    _citizenshipBackController =
        TextEditingController(text: p?.citizenshipPhotoBackUrl ?? '');
    _ninNumberController = TextEditingController(text: p?.ninNumber ?? '');
    _ninPhotoController = TextEditingController(text: p?.ninPhotoUrl ?? '');
    _panNumberController = TextEditingController(text: p?.panNumber ?? '');
    _panPhotoController = TextEditingController(text: p?.panPhotoUrl ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _grandfatherNameController.dispose();
    _addressController.dispose();
    _basicSalaryController.dispose();
    _bonusController.dispose();
    _ssfController.dispose();
    _citController.dispose();
    _insuranceController.dispose();
    _photoUrlController.dispose();
    _citizenshipNumberController.dispose();
    _citizenshipFrontController.dispose();
    _citizenshipBackController.dispose();
    _ninNumberController.dispose();
    _ninPhotoController.dispose();
    _panNumberController.dispose();
    _panPhotoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.initialProfile != null ? 'Edit HR Profile' : 'New Employee Record',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
          ),
          IconButton(
            icon: Icon(Icons.close, color: labelColor),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 520,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: labelColor,
              indicatorColor: colorScheme.primary,
              tabs: const [
                Tab(text: 'Personal & Family'),
                Tab(text: 'Office & Payroll'),
                Tab(text: 'Identity & Documents'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Personal & Family
                  _buildPersonalTab(labelColor),

                  // Tab 2: Office & Payroll
                  _buildPayrollTab(labelColor),

                  // Tab 3: Documents
                  _buildDocumentsTab(labelColor),
                ],
              ),
            ),
          ],
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
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Employee File'),
        ),
      ],
    );
  }

  Widget _buildPersonalTab(Color labelColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.isNewUser) ...[
            _buildTextField('Account Email Address', _emailController, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildTextField('Account Password', _passwordController, isPassword: true),
            const SizedBox(height: 10),
          ],
          _buildTextField('Full Name', _nameController),
          const SizedBox(height: 10),
          _buildTextField('Designation / Role', _designationController),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date of Birth (DOB)', style: TextStyle(fontSize: 12, color: labelColor)),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cake, size: 16),
                      label: Text(_dob != null ? formatNepaliDate(_dob!, 'dd MMM yyyy') : 'Select DOB'),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Date of Birth (Nepali BS)',
                          initialStart: _dob ?? DateTime(1995, 1, 1),
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) setState(() => _dob = picked['start']!);
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
                    Text('Blood Group', style: TextStyle(fontSize: 12, color: labelColor)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _bloodGroup,
                      isDense: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'N/A']
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _bloodGroup = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField('Father\'s Name', _fatherNameController),
          const SizedBox(height: 10),
          _buildTextField('Mother\'s Name', _motherNameController),
          const SizedBox(height: 10),
          _buildTextField('Grandfather\'s Name', _grandfatherNameController),
          const SizedBox(height: 10),
          _buildTextField('Permanent Address', _addressController, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildPayrollTab(Color labelColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Office Join Date', style: TextStyle(fontSize: 12, color: labelColor)),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.work_history, size: 16),
                      label: Text(formatNepaliDate(_officeJoinDate, 'dd MMM yyyy')),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Office Join Date (Nepali BS)',
                          initialStart: _officeJoinDate,
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) setState(() => _officeJoinDate = picked['start']!);
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
                    Text('Office Leaving Date', style: TextStyle(fontSize: 12, color: labelColor)),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.output, size: 16),
                      label: Text(_officeLeavingDate != null
                          ? formatNepaliDate(_officeLeavingDate!, 'dd MMM yyyy')
                          : 'N/A (Active)'),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Office Leaving Date (Nepali BS)',
                          initialStart: _officeLeavingDate ?? DateTime.now(),
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) setState(() => _officeLeavingDate = picked['start']!);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField('Basic Salary (NPR)', _basicSalaryController, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _buildTextField('Bonus (NPR)', _bonusController, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _buildTextField('SSF Allowance (NPR)', _ssfController, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _buildTextField('CIT Contribution (NPR)', _citController, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _buildTextField('Insurance Allowance (NPR)', _insuranceController, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(Color labelColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTextField('Employee Photo URL / Path', _photoUrlController),
          const SizedBox(height: 10),
          _buildTextField('Citizenship Card Number', _citizenshipNumberController),
          const SizedBox(height: 10),
          _buildTextField('Citizenship Front Photo URL', _citizenshipFrontController),
          const SizedBox(height: 10),
          _buildTextField('Citizenship Back Photo URL', _citizenshipBackController),
          const SizedBox(height: 10),
          _buildTextField('NIN (National ID) Number', _ninNumberController),
          const SizedBox(height: 10),
          _buildTextField('NIN Card Photo URL', _ninPhotoController),
          const SizedBox(height: 10),
          _buildTextField('PAN Card Number', _panNumberController),
          const SizedBox(height: 10),
          _buildTextField('PAN Card Photo URL', _panPhotoController),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      bool isPassword = false}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String finalUserId = widget.userId;

      // 1. If registering a brand new employee user account:
      if (widget.isNewUser) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        if (email.isEmpty || password.isEmpty) {
          throw 'Please enter email address and password for the new employee.';
        }

        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        finalUserId = credential.user!.uid;

        // Write user document to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(finalUserId)
            .set({
          'id': finalUserId,
          'name': _nameController.text.trim(),
          'email': email,
          'role': 'staff',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Save complete Employee Profile Record
      final profile = EmployeeProfileEntity(
        id: widget.initialProfile?.id ?? const Uuid().v4(),
        userId: finalUserId,
        name: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        dob: _dob,
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        grandfatherName: _grandfatherNameController.text.trim(),
        address: _addressController.text.trim(),
        bloodGroup: _bloodGroup,
        officeJoinDate: _officeJoinDate,
        officeLeavingDate: _officeLeavingDate,
        basicSalary: double.tryParse(_basicSalaryController.text) ?? 0.0,
        bonus: double.tryParse(_bonusController.text) ?? 0.0,
        ssf: double.tryParse(_ssfController.text) ?? 0.0,
        cit: double.tryParse(_citController.text) ?? 0.0,
        insurance: double.tryParse(_insuranceController.text) ?? 0.0,
        photoUrl: _photoUrlController.text.trim(),
        citizenshipNumber: _citizenshipNumberController.text.trim(),
        citizenshipPhotoFrontUrl: _citizenshipFrontController.text.trim(),
        citizenshipPhotoBackUrl: _citizenshipBackController.text.trim(),
        ninNumber: _ninNumberController.text.trim(),
        ninPhotoUrl: _ninPhotoController.text.trim(),
        panNumber: _panNumberController.text.trim(),
        panPhotoUrl: _panPhotoController.text.trim(),
        createdAt: widget.initialProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(employeeProfileNotifierProvider.notifier)
          .saveProfile(profile);
      ref.invalidate(usersStreamProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee profile updated successfully!'),
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
