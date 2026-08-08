import 'package:order_app/domain/entities/employee_profile_entity.dart';

class EmployeeProfileModel extends EmployeeProfileEntity {
  const EmployeeProfileModel({
    required super.id,
    required super.userId,
    required super.name,
    super.designation,
    super.dob,
    super.fatherName,
    super.motherName,
    super.grandfatherName,
    super.address,
    super.bloodGroup,
    required super.officeJoinDate,
    super.officeLeavingDate,
    super.basicSalary,
    super.dearnessAllowance,
    super.bonus,
    super.ssf,
    super.cit,
    super.insurance,
    super.tds,
    super.photoUrl,
    super.citizenshipNumber,
    super.citizenshipPhotoFrontUrl,
    super.citizenshipPhotoBackUrl,
    super.ninNumber,
    super.ninPhotoUrl,
    super.panNumber,
    super.panPhotoUrl,
    required super.createdAt,
    required super.updatedAt,
    super.allowedLeaves,
  });

  factory EmployeeProfileModel.fromJson(Map<String, dynamic> json) {
    return EmployeeProfileModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Employee',
      designation: json['designation'] as String? ?? 'Staff Member',
      dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
      fatherName: json['fatherName'] as String? ?? '',
      motherName: json['motherName'] as String? ?? '',
      grandfatherName: json['grandfatherName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? 'N/A',
      officeJoinDate: json['officeJoinDate'] != null
          ? DateTime.parse(json['officeJoinDate'] as String)
          : DateTime.now(),
      officeLeavingDate: json['officeLeavingDate'] != null
          ? DateTime.parse(json['officeLeavingDate'] as String)
          : null,
      basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
      dearnessAllowance: (json['dearnessAllowance'] as num?)?.toDouble() ?? 0.0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0.0,
      ssf: (json['ssf'] as num?)?.toDouble() ?? 0.0,
      cit: (json['cit'] as num?)?.toDouble() ?? 0.0,
      insurance: (json['insurance'] as num?)?.toDouble() ?? 0.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photoUrl'] as String?,
      citizenshipNumber: json['citizenshipNumber'] as String? ?? '',
      citizenshipPhotoFrontUrl: json['citizenshipPhotoFrontUrl'] as String?,
      citizenshipPhotoBackUrl: json['citizenshipPhotoBackUrl'] as String?,
      ninNumber: json['ninNumber'] as String? ?? '',
      ninPhotoUrl: json['ninPhotoUrl'] as String?,
      panNumber: json['panNumber'] as String? ?? '',
      panPhotoUrl: json['panPhotoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      allowedLeaves: (json['allowedLeaves'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'designation': designation,
      if (dob != null) 'dob': dob!.toIso8601String(),
      'fatherName': fatherName,
      'motherName': motherName,
      'grandfatherName': grandfatherName,
      'address': address,
      'bloodGroup': bloodGroup,
      'officeJoinDate': officeJoinDate.toIso8601String(),
      if (officeLeavingDate != null)
        'officeLeavingDate': officeLeavingDate!.toIso8601String(),
      'basicSalary': basicSalary,
      'dearnessAllowance': dearnessAllowance,
      'bonus': bonus,
      'ssf': ssf,
      'cit': cit,
      'insurance': insurance,
      'tds': tds,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'citizenshipNumber': citizenshipNumber,
      if (citizenshipPhotoFrontUrl != null)
        'citizenshipPhotoFrontUrl': citizenshipPhotoFrontUrl,
      if (citizenshipPhotoBackUrl != null)
        'citizenshipPhotoBackUrl': citizenshipPhotoBackUrl,
      'ninNumber': ninNumber,
      if (ninPhotoUrl != null) 'ninPhotoUrl': ninPhotoUrl,
      'panNumber': panNumber,
      if (panPhotoUrl != null) 'panPhotoUrl': panPhotoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'allowedLeaves': allowedLeaves,
    };
  }

  factory EmployeeProfileModel.fromEntity(EmployeeProfileEntity entity) {
    return EmployeeProfileModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      designation: entity.designation,
      dob: entity.dob,
      fatherName: entity.fatherName,
      motherName: entity.motherName,
      grandfatherName: entity.grandfatherName,
      address: entity.address,
      bloodGroup: entity.bloodGroup,
      officeJoinDate: entity.officeJoinDate,
      officeLeavingDate: entity.officeLeavingDate,
      basicSalary: entity.basicSalary,
      dearnessAllowance: entity.dearnessAllowance,
      bonus: entity.bonus,
      ssf: entity.ssf,
      cit: entity.cit,
      insurance: entity.insurance,
      tds: entity.tds,
      photoUrl: entity.photoUrl,
      citizenshipNumber: entity.citizenshipNumber,
      citizenshipPhotoFrontUrl: entity.citizenshipPhotoFrontUrl,
      citizenshipPhotoBackUrl: entity.citizenshipPhotoBackUrl,
      ninNumber: entity.ninNumber,
      ninPhotoUrl: entity.ninPhotoUrl,
      panNumber: entity.panNumber,
      panPhotoUrl: entity.panPhotoUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      allowedLeaves: entity.allowedLeaves,
    );
  }
}
