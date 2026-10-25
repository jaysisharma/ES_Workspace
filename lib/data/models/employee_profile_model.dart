import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';

class EmployeeProfileModel extends EmployeeProfileEntity {
  const EmployeeProfileModel({
    required super.id,
    required super.userId,
    super.email = '',
    required super.name,
    super.designation,
    super.department,
    super.dob,
    super.fatherName,
    super.motherName,
    super.grandfatherName,
    super.grandmotherName,
    super.spouseName,
    super.address,
    super.permanentAddress,
    super.temporaryAddress,
    super.gender,
    super.bloodGroup,
    super.maritalStatus,
    super.contactNumber,
    required super.officeJoinDate,
    super.officeLeavingDate,
    super.basicSalary,
    super.fuelAllowance,
    super.communicationAllowance,
    super.dearnessAllowance,
    super.bonus,
    super.ssf,
    super.cit,
    super.insurance,
    super.lifeInsurance,
    super.healthInsurance,
    super.tds,
    super.netPayableSalary,
    super.photoUrl,
    super.citizenshipNumber,
    super.citizenshipIssueDate,
    super.citizenshipPhotoFrontUrl,
    super.citizenshipPhotoBackUrl,
    super.ninNumber,
    super.ninPhotoUrl,
    super.panNumber,
    super.panPhotoUrl,
    super.citNumber,
    required super.createdAt,
    required super.updatedAt,
    super.allowedLeaves,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  factory EmployeeProfileModel.fromJson(Map<String, dynamic> json) {
    final rawAddress = json['address']?.toString() ?? '';
    final rawPermAddress = json['permanentAddress']?.toString() ?? '';
    final permAddress = rawPermAddress.isNotEmpty ? rawPermAddress : rawAddress;

    return EmployeeProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Employee',
      designation: json['designation']?.toString() ?? 'Staff Member',
      department: json['department']?.toString() ?? '',
      dob: _parseDate(json['dob']),
      fatherName: json['fatherName']?.toString() ?? '',
      motherName: json['motherName']?.toString() ?? '',
      grandfatherName: json['grandfatherName']?.toString() ?? '',
      grandmotherName: json['grandmotherName']?.toString() ?? '',
      spouseName: json['spouseName']?.toString() ?? '',
      address: permAddress,
      permanentAddress: permAddress,
      temporaryAddress: json['temporaryAddress']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'N/A',
      bloodGroup: json['bloodGroup']?.toString() ?? 'N/A',
      maritalStatus: json['maritalStatus']?.toString() ?? 'Single',
      contactNumber: json['contactNumber']?.toString() ?? (json['phone']?.toString() ?? ''),
      officeJoinDate: _parseDate(json['officeJoinDate']) ?? DateTime.now(),
      officeLeavingDate: _parseDate(json['officeLeavingDate']),
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
      fuelAllowance: (json['fuelAllowance'] as num?)?.toDouble() ?? 0.0,
      communicationAllowance:
          (json['communicationAllowance'] as num?)?.toDouble() ?? 0.0,
      dearnessAllowance: (json['dearnessAllowance'] as num?)?.toDouble() ?? 0.0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0.0,
      ssf: (json['ssf'] as num?)?.toDouble() ?? 0.0,
      cit: (json['cit'] as num?)?.toDouble() ?? 0.0,
      insurance: (json['insurance'] as num?)?.toDouble() ?? 0.0,
      lifeInsurance: (json['lifeInsurance'] as num?)?.toDouble() ?? 0.0,
      healthInsurance: (json['healthInsurance'] as num?)?.toDouble() ?? 0.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 0.0,
      netPayableSalary: (json['netPayableSalary'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photoUrl']?.toString(),
      citizenshipNumber: json['citizenshipNumber']?.toString() ?? '',
      citizenshipIssueDate: _parseDate(json['citizenshipIssueDate']),
      citizenshipPhotoFrontUrl: json['citizenshipPhotoFrontUrl']?.toString(),
      citizenshipPhotoBackUrl: json['citizenshipPhotoBackUrl']?.toString(),
      ninNumber: json['ninNumber']?.toString() ?? (json['nidNumber']?.toString() ?? ''),
      ninPhotoUrl: json['ninPhotoUrl']?.toString(),
      panNumber: json['panNumber']?.toString() ?? '',
      panPhotoUrl: json['panPhotoUrl']?.toString(),
      citNumber: json['citNumber']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
      allowedLeaves: (json['allowedLeaves'] as Map?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              (v is num) ? v.toInt() : (int.tryParse(v.toString()) ?? 0),
            ),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'email': email,
      'name': name,
      'designation': designation,
      'department': department,
      if (dob != null) 'dob': dob!.toIso8601String(),
      'fatherName': fatherName,
      'motherName': motherName,
      'grandfatherName': grandfatherName,
      'grandmotherName': grandmotherName,
      'spouseName': spouseName,
      'address': permanentAddress.isNotEmpty ? permanentAddress : address,
      'permanentAddress': permanentAddress,
      'temporaryAddress': temporaryAddress,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'maritalStatus': maritalStatus,
      'contactNumber': contactNumber,
      'officeJoinDate': officeJoinDate.toIso8601String(),
      if (officeLeavingDate != null)
        'officeLeavingDate': officeLeavingDate!.toIso8601String(),
      'basicSalary': basicSalary,
      'fuelAllowance': fuelAllowance,
      'communicationAllowance': communicationAllowance,
      'dearnessAllowance': dearnessAllowance,
      'bonus': bonus,
      'ssf': ssf,
      'cit': cit,
      'insurance': insurance,
      'lifeInsurance': lifeInsurance,
      'healthInsurance': healthInsurance,
      'tds': tds,
      'netPayableSalary': netPayableSalary,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'citizenshipNumber': citizenshipNumber,
      if (citizenshipIssueDate != null)
        'citizenshipIssueDate': citizenshipIssueDate!.toIso8601String(),
      if (citizenshipPhotoFrontUrl != null)
        'citizenshipPhotoFrontUrl': citizenshipPhotoFrontUrl,
      if (citizenshipPhotoBackUrl != null)
        'citizenshipPhotoBackUrl': citizenshipPhotoBackUrl,
      'ninNumber': ninNumber,
      if (ninPhotoUrl != null) 'ninPhotoUrl': ninPhotoUrl,
      'panNumber': panNumber,
      if (panPhotoUrl != null) 'panPhotoUrl': panPhotoUrl,
      'citNumber': citNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'allowedLeaves': allowedLeaves,
    };
  }

  factory EmployeeProfileModel.fromEntity(EmployeeProfileEntity entity) {
    return EmployeeProfileModel(
      id: entity.id,
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      designation: entity.designation,
      department: entity.department,
      dob: entity.dob,
      fatherName: entity.fatherName,
      motherName: entity.motherName,
      grandfatherName: entity.grandfatherName,
      grandmotherName: entity.grandmotherName,
      spouseName: entity.spouseName,
      address: entity.address,
      permanentAddress: entity.permanentAddress,
      temporaryAddress: entity.temporaryAddress,
      gender: entity.gender,
      bloodGroup: entity.bloodGroup,
      maritalStatus: entity.maritalStatus,
      contactNumber: entity.contactNumber,
      officeJoinDate: entity.officeJoinDate,
      officeLeavingDate: entity.officeLeavingDate,
      basicSalary: entity.basicSalary,
      fuelAllowance: entity.fuelAllowance,
      communicationAllowance: entity.communicationAllowance,
      dearnessAllowance: entity.dearnessAllowance,
      bonus: entity.bonus,
      ssf: entity.ssf,
      cit: entity.cit,
      insurance: entity.insurance,
      lifeInsurance: entity.lifeInsurance,
      healthInsurance: entity.healthInsurance,
      tds: entity.tds,
      netPayableSalary: entity.netPayableSalary,
      photoUrl: entity.photoUrl,
      citizenshipNumber: entity.citizenshipNumber,
      citizenshipIssueDate: entity.citizenshipIssueDate,
      citizenshipPhotoFrontUrl: entity.citizenshipPhotoFrontUrl,
      citizenshipPhotoBackUrl: entity.citizenshipPhotoBackUrl,
      ninNumber: entity.ninNumber,
      ninPhotoUrl: entity.ninPhotoUrl,
      panNumber: entity.panNumber,
      panPhotoUrl: entity.panPhotoUrl,
      citNumber: entity.citNumber,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      allowedLeaves: entity.allowedLeaves,
    );
  }
}
