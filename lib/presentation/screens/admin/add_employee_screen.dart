import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/core/services/admin_auth_service.dart';
import 'package:order_app/core/services/synology_storage_service.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/admin/employee_detail_screen.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';

class AddEmployeeScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String? userEmail;
  final UserRole? userRole;
  final bool isNewUser;
  final bool isStaffSelfEdit;
  final EmployeeProfileEntity? initialProfile;

  const AddEmployeeScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userRole,
    this.isNewUser = false,
    this.isStaffSelfEdit = false,
    this.initialProfile,
  });

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late UserRole _selectedRole;
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
  late TextEditingController _fuelAllowanceController;
  late TextEditingController _communicationAllowanceController;
  late TextEditingController _dearnessAllowanceController;
  late TextEditingController _bonusController;
  late TextEditingController _ssfController;
  late TextEditingController _citController;
  late TextEditingController _lifeInsuranceController;
  late TextEditingController _healthInsuranceController;
  late TextEditingController _tdsController;
  late TextEditingController _netPayableSalaryController;

  late TextEditingController _photoUrlController;
  late TextEditingController _citizenshipNumberController;
  late TextEditingController _citizenshipFrontController;
  late TextEditingController _citizenshipBackController;
  late TextEditingController _ninNumberController;
  late TextEditingController _ninPhotoController;
  late TextEditingController _panNumberController;
  late TextEditingController _panPhotoController;

  bool _isSaving = false;
  late Map<String, TextEditingController> _leaveAllocationsControllers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isStaffSelfEdit ? 2 : 4,
      vsync: this,
    );

    final p = widget.initialProfile;

    _emailController = TextEditingController(text: widget.userEmail ?? '');
    _passwordController = TextEditingController();
    _selectedRole = widget.userRole ?? UserRole.staff;
    _nameController = TextEditingController(text: p?.name ?? widget.userName);
    _designationController = TextEditingController(
      text: p?.designation ?? 'Event Specialist',
    );
    _fatherNameController = TextEditingController(text: p?.fatherName ?? '');
    _motherNameController = TextEditingController(text: p?.motherName ?? '');
    _grandfatherNameController = TextEditingController(
      text: p?.grandfatherName ?? '',
    );
    _addressController = TextEditingController(text: p?.address ?? '');
    _bloodGroup = (p?.bloodGroup.isNotEmpty == true) ? p!.bloodGroup : 'A+';

    _dob = p?.dob;
    _officeJoinDate = p?.officeJoinDate ?? DateTime.now();
    _officeLeavingDate = p?.officeLeavingDate;

    _basicSalaryController = TextEditingController(
      text: (p?.basicSalary != null && p!.basicSalary > 0) ? p.basicSalary.toStringAsFixed(0) : '0',
    );
    _fuelAllowanceController = TextEditingController(
      text: (p?.fuelAllowance != null && p!.fuelAllowance > 0) ? p.fuelAllowance.toStringAsFixed(0) : '0',
    );
    _communicationAllowanceController = TextEditingController(
      text: (p?.communicationAllowance != null && p!.communicationAllowance > 0) ? p.communicationAllowance.toStringAsFixed(0) : '0',
    );
    _dearnessAllowanceController = TextEditingController(
      text: (p?.dearnessAllowance != null && p!.dearnessAllowance > 0) ? p.dearnessAllowance.toStringAsFixed(0) : '0',
    );
    _bonusController = TextEditingController(
      text: (p?.bonus != null && p!.bonus > 0) ? p.bonus.toStringAsFixed(0) : '0',
    );
    _ssfController = TextEditingController(
      text: (p?.ssf != null && p!.ssf > 0) ? p.ssf.toStringAsFixed(0) : '0',
    );
    _citController = TextEditingController(
      text: (p?.cit != null && p!.cit > 0) ? p.cit.toStringAsFixed(0) : '0',
    );
    final initialLife = (p?.lifeInsurance != null && p!.lifeInsurance > 0)
        ? p.lifeInsurance
        : (p?.insurance ?? 0.0);
    _lifeInsuranceController = TextEditingController(
      text: initialLife > 0 ? initialLife.toStringAsFixed(0) : '0',
    );
    _healthInsuranceController = TextEditingController(
      text: (p?.healthInsurance != null && p!.healthInsurance > 0) ? p.healthInsurance.toStringAsFixed(0) : '0',
    );
    _tdsController = TextEditingController(
      text: (p?.tds != null && p!.tds > 0) ? p.tds.toStringAsFixed(0) : '0',
    );
    final initialNet = (p?.netPayableSalary != null && p!.netPayableSalary > 0)
        ? p.netPayableSalary
        : (p?.netSalary ?? 0.0);
    _netPayableSalaryController = TextEditingController(
      text: initialNet > 0 ? initialNet.toStringAsFixed(0) : '0',
    );

    _photoUrlController = TextEditingController(text: p?.photoUrl ?? '');
    _citizenshipNumberController = TextEditingController(
      text: p?.citizenshipNumber ?? '',
    );
    _citizenshipFrontController = TextEditingController(
      text: p?.citizenshipPhotoFrontUrl ?? '',
    );
    _citizenshipBackController = TextEditingController(
      text: p?.citizenshipPhotoBackUrl ?? '',
    );
    _ninNumberController = TextEditingController(text: p?.ninNumber ?? '');
    _ninPhotoController = TextEditingController(text: p?.ninPhotoUrl ?? '');
    _panNumberController = TextEditingController(text: p?.panNumber ?? '');
    _panPhotoController = TextEditingController(text: p?.panPhotoUrl ?? '');

    final initialLeaves = p?.allowedLeaves ?? {};
    _leaveAllocationsControllers = {};
    for (final type in EmployeeProfileEntity.defaultAllowedLeaves.keys) {
      final initialVal =
          initialLeaves[type] ??
          EmployeeProfileEntity.defaultAllowedLeaves[type] ??
          0;
      _leaveAllocationsControllers[type] = TextEditingController(
        text: initialVal.toString(),
      );
    }
  }

  void _calculateSuggestedNet() {
    final basic = double.tryParse(_basicSalaryController.text) ?? 0.0;
    final fuel = double.tryParse(_fuelAllowanceController.text) ?? 0.0;
    final comm = double.tryParse(_communicationAllowanceController.text) ?? 0.0;
    final da = double.tryParse(_dearnessAllowanceController.text) ?? 0.0;
    final bonus = double.tryParse(_bonusController.text) ?? 0.0;
    final gross = basic + fuel + comm + da + bonus;

    final ssf = double.tryParse(_ssfController.text) ?? 0.0;
    final cit = double.tryParse(_citController.text) ?? 0.0;
    final life = double.tryParse(_lifeInsuranceController.text) ?? 0.0;
    final health = double.tryParse(_healthInsuranceController.text) ?? 0.0;
    final tds = double.tryParse(_tdsController.text) ?? 0.0;
    final deductions = ssf + cit + life + health + tds;

    final net = (gross - deductions).clamp(0.0, double.infinity);
    _netPayableSalaryController.text = net.toStringAsFixed(0);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _grandfatherNameController.dispose();
    _addressController.dispose();
    _basicSalaryController.dispose();
    _fuelAllowanceController.dispose();
    _communicationAllowanceController.dispose();
    _dearnessAllowanceController.dispose();
    _bonusController.dispose();
    _ssfController.dispose();
    _citController.dispose();
    _lifeInsuranceController.dispose();
    _healthInsuranceController.dispose();
    _tdsController.dispose();
    _netPayableSalaryController.dispose();
    _photoUrlController.dispose();
    _citizenshipNumberController.dispose();
    _citizenshipFrontController.dispose();
    _citizenshipBackController.dispose();
    _ninNumberController.dispose();
    _ninPhotoController.dispose();
    _panNumberController.dispose();
    _panPhotoController.dispose();
    for (final c in _leaveAllocationsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isStaffSelfEdit
              ? 'Edit My Profile Details'
              : (widget.isNewUser
                  ? 'New Employee Registration'
                  : 'Edit Employee File: ${_nameController.text}'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _saveProfile,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: labelColor,
          indicatorColor: colorScheme.primary,
          tabs: widget.isStaffSelfEdit
              ? const [
                  Tab(icon: Icon(Icons.person), text: 'Personal & Family'),
                  Tab(icon: Icon(Icons.badge), text: 'Identity & Documents'),
                ]
              : const [
                  Tab(icon: Icon(Icons.person), text: 'Personal & Family'),
                  Tab(icon: Icon(Icons.work), text: 'Office & Payroll'),
                  Tab(icon: Icon(Icons.badge), text: 'Identity & Documents'),
                  Tab(icon: Icon(Icons.event_busy), text: 'Leave Allocations'),
                ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(20.0),
          child: TabBarView(
            controller: _tabController,
            children: widget.isStaffSelfEdit
                ? [
                    _buildPersonalTab(labelColor, colorScheme),
                    _buildDocumentsTab(labelColor, colorScheme),
                  ]
                : [
                    _buildPersonalTab(labelColor, colorScheme),
                    _buildPayrollTab(labelColor, colorScheme),
                    _buildDocumentsTab(labelColor, colorScheme),
                    _buildLeaveAllocationsTab(labelColor, colorScheme),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalTab(Color labelColor, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isStaffSelfEdit) ...[
            Text(
              'Account Credentials',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              'Account Email Address',
              _emailController,
              enabled: false,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 4),
            Text(
              '🔒 Email and password are managed by administration and cannot be changed.',
              style: TextStyle(fontSize: 11, color: labelColor, fontStyle: FontStyle.italic),
            ),
            const Divider(height: 28),
          ] else if (widget.isNewUser) ...[
            Text(
              'Account Authentication Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              'Account Email Address',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Account Password (Min 6 characters)',
              _passwordController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            _buildRoleSelector(labelColor),
            const Divider(height: 32),
          ] else ...[
            Text(
              'Account Authentication & Login Credentials',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              'Account Email Address',
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Change Password (Optional / Leave blank to keep current)',
              _passwordController,
              isPassword: true,
            ),
            const SizedBox(height: 12),
            _buildRoleSelector(labelColor),
            const Divider(height: 32),
          ],
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField('Full Name', _nameController),
          const SizedBox(height: 12),
          _buildTextField('Designation / Role', _designationController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date of Birth (BS Calendar)',
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                        _dob != null
                            ? formatNepaliDate(_dob!, 'dd MMM yyyy (BS)')
                            : 'Select DOB (BS Calendar)',
                      ),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Date of Birth (Nepali BS)',
                          initialStart: _dob ?? DateTime(1995, 1, 1),
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) {
                          setState(() => _dob = picked['start']!);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blood Group',
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _bloodGroup,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                                'A+',
                                'A-',
                                'B+',
                                'B-',
                                'O+',
                                'O-',
                                'AB+',
                                'AB-',
                                'N/A',
                              ]
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                              )
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
          const Divider(height: 32),
          Text(
            'Family Background Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField('Father\'s Name', _fatherNameController),
          const SizedBox(height: 12),
          _buildTextField('Mother\'s Name', _motherNameController),
          const SizedBox(height: 12),
          _buildTextField('Grandfather\'s Name', _grandfatherNameController),
          const SizedBox(height: 12),
          _buildTextField('Permanent Address', _addressController, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildPayrollTab(Color labelColor, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Office Employment Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office Join Date (BS Calendar)',
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.work_history, size: 16),
                      label: Text(
                        formatNepaliDate(_officeJoinDate, 'dd MMM yyyy (BS)'),
                      ),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Office Join Date (Nepali BS)',
                          initialStart: _officeJoinDate,
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) {
                          setState(() => _officeJoinDate = picked['start']!);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office Leaving Date (BS Calendar)',
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.output, size: 16),
                      label: Text(
                        _officeLeavingDate != null
                            ? formatNepaliDate(
                                _officeLeavingDate!,
                                'dd MMM yyyy (BS)',
                              )
                            : 'Active Employee',
                      ),
                      onPressed: () async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Select Office Leaving Date (Nepali BS)',
                          initialStart: _officeLeavingDate ?? DateTime.now(),
                          allowRange: false,
                        );
                        if (picked != null && picked['start'] != null) {
                          setState(() => _officeLeavingDate = picked['start']!);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Monthly Allowances & Earnings (NPR)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Basic Salary (NPR)',
            _basicSalaryController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Fuel Allowance (NPR)',
            _fuelAllowanceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Communication Allowance (NPR)',
            _communicationAllowanceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Dearness Allowance (DA)',
            _dearnessAllowanceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Bonus / Performance Allowance',
            _bonusController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Computed Gross Salary Box
          Builder(
            builder: (context) {
              final basic = double.tryParse(_basicSalaryController.text) ?? 0.0;
              final fuel = double.tryParse(_fuelAllowanceController.text) ?? 0.0;
              final comm = double.tryParse(_communicationAllowanceController.text) ?? 0.0;
              final da = double.tryParse(_dearnessAllowanceController.text) ?? 0.0;
              final bonus = double.tryParse(_bonusController.text) ?? 0.0;
              final gross = basic + fuel + comm + da + bonus;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gross Salary (Basic + Fuel + Comm + DA + Bonus):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                    ),
                    Text(
                      'NPR ${gross.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Deductions & Contributions (NPR)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'SSF Contribution (Social Security)',
            _ssfController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Life Insurance Premium',
            _lifeInsuranceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'Health Insurance Premium',
            _healthInsuranceController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'CIT Contribution (Citizen Investment Trust)',
            _citController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            'TDS (Tax Deducted at Source)',
            _tdsController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          // Net Payable Monthly Salary (In Hand)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Payable Monthly Salary (In Hand)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calculate_outlined, size: 16),
                      label: const Text('Calculate Suggested', style: TextStyle(fontSize: 12)),
                      onPressed: _calculateSuggestedNet,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  'Net In-Hand Salary (NPR)',
                  _netPayableSalaryController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                Text(
                  '💡 Manually enterable. You can edit this directly or click "Calculate Suggested" above.',
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(Color labelColor, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employee Photo & Identity Documentation',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Profile Photo
          _buildImageUploadCard(
            title: 'Employee Profile Photo',
            controller: _photoUrlController,
            colorScheme: colorScheme,
            labelColor: labelColor,
          ),
          const SizedBox(height: 16),

          // 2. Citizenship Card
          _buildTextField(
            'Citizenship Card Number',
            _citizenshipNumberController,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildImageUploadCard(
                  title: 'Citizenship Front Photo',
                  controller: _citizenshipFrontController,
                  colorScheme: colorScheme,
                  labelColor: labelColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildImageUploadCard(
                  title: 'Citizenship Back Photo',
                  controller: _citizenshipBackController,
                  colorScheme: colorScheme,
                  labelColor: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. NIN Card
          _buildTextField('NIN (National ID) Number', _ninNumberController),
          const SizedBox(height: 10),
          _buildImageUploadCard(
            title: 'NIN (National ID) Card Photo',
            controller: _ninPhotoController,
            colorScheme: colorScheme,
            labelColor: labelColor,
          ),
          const SizedBox(height: 16),

          // 4. PAN Card
          _buildTextField('PAN Card Number', _panNumberController),
          const SizedBox(height: 10),
          _buildImageUploadCard(
            title: 'PAN Card Photo',
            controller: _panPhotoController,
            colorScheme: colorScheme,
            labelColor: labelColor,
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required TextEditingController controller,
    required ColorScheme colorScheme,
    required Color labelColor,
  }) {
    final hasImage = controller.text.trim().isNotEmpty;
    final value = controller.text.trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (hasImage)
                  TextButton.icon(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                    onPressed: () => setState(() => controller.clear()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _renderImageWidget(value),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 28,
                            color: labelColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No document image attached',
                            style: TextStyle(fontSize: 11, color: labelColor),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 14),
                    label: const Text('Camera', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () =>
                        _pickImageForController(controller, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 14),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () => _pickImageForController(
                      controller,
                      ImageSource.gallery,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderImageWidget(String value) {
    if (value.startsWith('data:image')) {
      try {
        final base64Data = value.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(bytes, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
      } catch (_) {}
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(value, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
    } else {
      final file = File(value);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
      }
    }

    return const Center(child: Text('Image Attached'));
  }

  Future<void> _pickImageForController(
    TextEditingController controller,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1000,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final filename = 'emp_doc_${DateTime.now().millisecondsSinceEpoch}';

        // Upload to Synology NAS (falls back to local data URI if disabled/offline)
        final uploadedUrl = await SynologyStorageService.uploadImageBytes(
          bytes: bytes,
          filename: filename,
        );

        setState(() {
          controller.text = uploadedUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isPassword = false,
    bool readOnly = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLines: maxLines,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRoleSelector(Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Access Role',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserRole>(
              value: _selectedRole,
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
                      Text(
                        role.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newRole) {
                if (newRole != null) {
                  setState(() => _selectedRole = newRole);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String finalUserId = widget.userId;

      // 1. Register Auth account if creating a new employee
      if (widget.isNewUser) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        if (email.isEmpty || password.isEmpty) {
          throw 'Please enter email address and password for the new employee.';
        }

        final createdUser = await AdminAuthService.createEmployeeUser(
          email: email,
          password: password,
          name: _nameController.text.trim(),
          role: _selectedRole,
          isActive: true,
        );
        finalUserId = createdUser.id;
      }

      // 2. Save Employee Profile Record
      final profile = EmployeeProfileEntity(
        id: widget.initialProfile?.id ?? const Uuid().v4(),
        userId: finalUserId,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : (widget.userEmail ?? (widget.initialProfile?.email ?? '')),
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
        basicSalary: double.tryParse(_basicSalaryController.text) ?? (widget.initialProfile?.basicSalary ?? 0.0),
        fuelAllowance: double.tryParse(_fuelAllowanceController.text) ?? (widget.initialProfile?.fuelAllowance ?? 0.0),
        communicationAllowance:
            double.tryParse(_communicationAllowanceController.text) ?? (widget.initialProfile?.communicationAllowance ?? 0.0),
        dearnessAllowance:
            double.tryParse(_dearnessAllowanceController.text) ?? (widget.initialProfile?.dearnessAllowance ?? 0.0),
        bonus: double.tryParse(_bonusController.text) ?? (widget.initialProfile?.bonus ?? 0.0),
        ssf: double.tryParse(_ssfController.text) ?? (widget.initialProfile?.ssf ?? 0.0),
        cit: double.tryParse(_citController.text) ?? (widget.initialProfile?.cit ?? 0.0),
        lifeInsurance: double.tryParse(_lifeInsuranceController.text) ?? (widget.initialProfile?.lifeInsurance ?? 0.0),
        healthInsurance: double.tryParse(_healthInsuranceController.text) ?? (widget.initialProfile?.healthInsurance ?? 0.0),
        insurance: (double.tryParse(_lifeInsuranceController.text) ?? (widget.initialProfile?.lifeInsurance ?? 0.0)) +
            (double.tryParse(_healthInsuranceController.text) ?? (widget.initialProfile?.healthInsurance ?? 0.0)),
        tds: double.tryParse(_tdsController.text) ?? (widget.initialProfile?.tds ?? 0.0),
        netPayableSalary:
            double.tryParse(_netPayableSalaryController.text) ?? (widget.initialProfile?.netPayableSalary ?? 0.0),
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
        allowedLeaves: widget.isStaffSelfEdit
            ? (widget.initialProfile?.allowedLeaves ?? {})
            : _leaveAllocationsControllers.map(
                (key, controller) =>
                    MapEntry(key, int.tryParse(controller.text) ?? 0),
              ),
      );

      await ref
          .read(employeeProfileNotifierProvider.notifier)
          .saveProfile(profile);

      if (!widget.isNewUser && !widget.isStaffSelfEdit) {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (password.isNotEmpty && password.length < 6) {
          throw 'Password must be at least 6 characters.';
        }

        await AdminAuthService.updateEmployeeCredentials(
          userId: widget.userId,
          oldEmail: widget.userEmail ?? '',
          newEmail: email,
          newPassword: password.isNotEmpty ? password : null,
          role: _selectedRole,
          name: _nameController.text.trim(),
          profileId: profile.id,
        );
      } else if (widget.isStaffSelfEdit) {
        // Update display name in Firestore user profile without touching credentials
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .set({
            'name': _nameController.text.trim(),
            'displayName': _nameController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      ref.invalidate(usersStreamProvider);
      ref.invalidate(employeeProfilesStreamProvider);

      final updatedEmail = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : (widget.userEmail ?? '');

      final newUser = UserEntity(
        id: finalUserId,
        name: _nameController.text.trim(),
        email: updatedEmail,
        role: _selectedRole,
        isActive: true,
      );

      if (mounted) {
        if (widget.isNewUser) {
          context.pushReplacementPage(
            EmployeeDetailScreen(user: newUser, initialProfile: profile),
          );
        } else {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee profile saved successfully!'),
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

  Widget _buildLeaveAllocationsTab(Color labelColor, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave & Absence Entitlements',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Specify the maximum number of days allowed per year for each leave category.',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 20),
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
                  childAspectRatio: isMobile ? 4.5 : 2.8,
                ),
                itemCount: _leaveAllocationsControllers.length,
                itemBuilder: (context, index) {
                  final key = _leaveAllocationsControllers.keys.elementAt(
                    index,
                  );
                  final controller = _leaveAllocationsControllers[key]!;
                  return _buildTextField(
                    key,
                    controller,
                    keyboardType: TextInputType.number,
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
