class EmployeeProfileEntity {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String designation;
  final String department;
  final DateTime? dob;
  final String fatherName;
  final String motherName;
  final String grandfatherName;
  final String grandmotherName;
  final String spouseName;
  final String address;
  final String permanentAddress;
  final String temporaryAddress;
  final String gender;
  final String bloodGroup;
  final String maritalStatus;
  final String contactNumber;
  final DateTime officeJoinDate;
  final DateTime? officeLeavingDate;
  final double basicSalary;
  final double fuelAllowance;
  final double communicationAllowance;
  final double dearnessAllowance;
  final double bonus;
  final double ssf;
  final double cit;
  final double insurance;
  final double lifeInsurance;
  final double healthInsurance;
  final double tds;
  final double netPayableSalary;
  final String? photoUrl;
  final String citizenshipNumber;
  final DateTime? citizenshipIssueDate;
  final String? citizenshipPhotoFrontUrl;
  final String? citizenshipPhotoBackUrl;
  final String ninNumber;
  final String? ninPhotoUrl;
  final String panNumber;
  final String? panPhotoUrl;
  final String citNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> allowedLeaves;

  static const Map<String, int> defaultAllowedLeaves = {
    'Casual Leave': 12,
    'Sick Leave': 12,
    'Maternity Leave': 60,
    'Paternity Leave': 15,
    'Mourning Leave': 15,
    'Festive Leave': 10,
  };

  const EmployeeProfileEntity({
    required this.id,
    required this.userId,
    this.email = '',
    required this.name,
    this.designation = 'Staff Member',
    this.department = '',
    this.dob,
    this.fatherName = '',
    this.motherName = '',
    this.grandfatherName = '',
    this.grandmotherName = '',
    this.spouseName = '',
    this.address = '',
    this.permanentAddress = '',
    this.temporaryAddress = '',
    this.gender = 'N/A',
    this.bloodGroup = 'N/A',
    this.maritalStatus = 'Single',
    this.contactNumber = '',
    required this.officeJoinDate,
    this.officeLeavingDate,
    this.basicSalary = 0.0,
    this.fuelAllowance = 0.0,
    this.communicationAllowance = 0.0,
    this.dearnessAllowance = 0.0,
    this.bonus = 0.0,
    this.ssf = 0.0,
    this.cit = 0.0,
    this.insurance = 0.0,
    this.lifeInsurance = 0.0,
    this.healthInsurance = 0.0,
    this.tds = 0.0,
    this.netPayableSalary = 0.0,
    this.photoUrl,
    this.citizenshipNumber = '',
    this.citizenshipIssueDate,
    this.citizenshipPhotoFrontUrl,
    this.citizenshipPhotoBackUrl,
    this.ninNumber = '',
    this.ninPhotoUrl,
    this.panNumber = '',
    this.panPhotoUrl,
    this.citNumber = '',
    required this.createdAt,
    required this.updatedAt,
    this.allowedLeaves = const {},
  });

  String get effectivePermanentAddress =>
      permanentAddress.isNotEmpty ? permanentAddress : address;

  String get nidNumber => ninNumber;

  Map<String, int> get effectiveAllowedLeaves {
    final Map<String, int> result = Map.from(defaultAllowedLeaves);
    allowedLeaves.forEach((key, value) {
      result[key] = value;
    });
    return result;
  }

  double get effectiveLifeInsurance =>
      lifeInsurance > 0 ? lifeInsurance : (insurance > 0 ? insurance : 0.0);
  double get effectiveHealthInsurance => healthInsurance;
  double get totalInsurance => effectiveLifeInsurance + effectiveHealthInsurance;

  double get grossSalary =>
      basicSalary + fuelAllowance + communicationAllowance + dearnessAllowance + bonus;
  double get totalDeductions =>
      ssf + cit + totalInsurance + tds;
  double get netSalary => netPayableSalary > 0
      ? netPayableSalary
      : (grossSalary - totalDeductions).clamp(0.0, double.infinity);
  double get totalPackage => grossSalary + ssf + cit + totalInsurance;

  EmployeeProfileEntity copyWith({
    String? id,
    String? userId,
    String? email,
    String? name,
    String? designation,
    String? department,
    DateTime? dob,
    String? fatherName,
    String? motherName,
    String? grandfatherName,
    String? grandmotherName,
    String? spouseName,
    String? address,
    String? permanentAddress,
    String? temporaryAddress,
    String? gender,
    String? bloodGroup,
    String? maritalStatus,
    String? contactNumber,
    DateTime? officeJoinDate,
    DateTime? officeLeavingDate,
    double? basicSalary,
    double? fuelAllowance,
    double? communicationAllowance,
    double? dearnessAllowance,
    double? bonus,
    double? ssf,
    double? cit,
    double? insurance,
    double? lifeInsurance,
    double? healthInsurance,
    double? tds,
    double? netPayableSalary,
    String? photoUrl,
    String? citizenshipNumber,
    DateTime? citizenshipIssueDate,
    String? citizenshipPhotoFrontUrl,
    String? citizenshipPhotoBackUrl,
    String? ninNumber,
    String? ninPhotoUrl,
    String? panNumber,
    String? panPhotoUrl,
    String? citNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? allowedLeaves,
  }) {
    return EmployeeProfileEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      dob: dob ?? this.dob,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      grandfatherName: grandfatherName ?? this.grandfatherName,
      grandmotherName: grandmotherName ?? this.grandmotherName,
      spouseName: spouseName ?? this.spouseName,
      address: address ?? this.address,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      temporaryAddress: temporaryAddress ?? this.temporaryAddress,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      contactNumber: contactNumber ?? this.contactNumber,
      officeJoinDate: officeJoinDate ?? this.officeJoinDate,
      officeLeavingDate: officeLeavingDate ?? this.officeLeavingDate,
      basicSalary: basicSalary ?? this.basicSalary,
      fuelAllowance: fuelAllowance ?? this.fuelAllowance,
      communicationAllowance:
          communicationAllowance ?? this.communicationAllowance,
      dearnessAllowance: dearnessAllowance ?? this.dearnessAllowance,
      bonus: bonus ?? this.bonus,
      ssf: ssf ?? this.ssf,
      cit: cit ?? this.cit,
      insurance: insurance ?? this.insurance,
      lifeInsurance: lifeInsurance ?? this.lifeInsurance,
      healthInsurance: healthInsurance ?? this.healthInsurance,
      tds: tds ?? this.tds,
      netPayableSalary: netPayableSalary ?? this.netPayableSalary,
      photoUrl: photoUrl ?? this.photoUrl,
      citizenshipNumber: citizenshipNumber ?? this.citizenshipNumber,
      citizenshipIssueDate: citizenshipIssueDate ?? this.citizenshipIssueDate,
      citizenshipPhotoFrontUrl:
          citizenshipPhotoFrontUrl ?? this.citizenshipPhotoFrontUrl,
      citizenshipPhotoBackUrl:
          citizenshipPhotoBackUrl ?? this.citizenshipPhotoBackUrl,
      ninNumber: ninNumber ?? this.ninNumber,
      ninPhotoUrl: ninPhotoUrl ?? this.ninPhotoUrl,
      panNumber: panNumber ?? this.panNumber,
      panPhotoUrl: panPhotoUrl ?? this.panPhotoUrl,
      citNumber: citNumber ?? this.citNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      allowedLeaves: allowedLeaves ?? this.allowedLeaves,
    );
  }
}
