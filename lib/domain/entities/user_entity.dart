enum UserRole {
  superAdmin,
  admin,
  director,
  companySecretary,
  seniorStaff,
  staff,
  finance,
  founder, // Legacy alias for Director / CEO
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.director:
      case UserRole.founder:
        return 'Director';
      case UserRole.companySecretary:
        return 'Company Secretary';
      case UserRole.seniorStaff:
        return 'Senior Staff';
      case UserRole.staff:
        return 'Staff';
      case UserRole.finance:
        return 'Finance';
    }
  }

  /// Check if the role is an executive/management role
  bool get isManagement {
    return this == UserRole.superAdmin ||
        this == UserRole.admin ||
        this == UserRole.director ||
        this == UserRole.founder ||
        this == UserRole.companySecretary ||
        this == UserRole.finance;
  }

  /// Whether this role has full administrative permissions (Super Admin, Admin, Director, Founder)
  bool get isAdminOrHigher {
    return this == UserRole.superAdmin ||
        this == UserRole.admin ||
        this == UserRole.director ||
        this == UserRole.founder;
  }

  /// Whether this role can edit orders and event details
  bool get canEditOrder => isAdminOrHigher;

  /// Whether this role can manage financial aspects of orders
  bool get canManageOrderFinances => canEditOrder || this == UserRole.finance;

  /// Whether this role can approve a leave request from an applicant with [applicantRole]
  bool canApproveLeaveFor(UserRole applicantRole) {
    switch (applicantRole) {
      case UserRole.staff:
        // Staff leave approved by Super Admin, Admin, Company Secretary, or Director
        return this == UserRole.superAdmin ||
            this == UserRole.admin ||
            this == UserRole.companySecretary ||
            this == UserRole.director ||
            this == UserRole.founder;
      case UserRole.seniorStaff:
        // Senior Staff leave approved by Company Secretary (or Director/Super Admin/Admin)
        return this == UserRole.superAdmin ||
            this == UserRole.companySecretary ||
            this == UserRole.director ||
            this == UserRole.founder ||
            this == UserRole.admin;
      case UserRole.companySecretary:
        // Company Secretary leave approved by Director or Super Admin
        return this == UserRole.superAdmin ||
            this == UserRole.director ||
            this == UserRole.founder;
      case UserRole.superAdmin:
      case UserRole.admin:
      case UserRole.finance:
      case UserRole.director:
      case UserRole.founder:
        // Management leaves approved by Director or Super Admin
        return this == UserRole.superAdmin ||
            this == UserRole.director ||
            this == UserRole.founder;
    }
  }
}

class UserEntity {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final String? lastLoginLocation;
  final double? lastLoginLatitude;
  final double? lastLoginLongitude;
  final String? lastLoginDevice;
  final String? lastLoginIp;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.lastLoginAt,
    this.lastLoginLocation,
    this.lastLoginLatitude,
    this.lastLoginLongitude,
    this.lastLoginDevice,
    this.lastLoginIp,
  });

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
    DateTime? lastLoginAt,
    String? lastLoginLocation,
    double? lastLoginLatitude,
    double? lastLoginLongitude,
    String? lastLoginDevice,
    String? lastLoginIp,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginLocation: lastLoginLocation ?? this.lastLoginLocation,
      lastLoginLatitude: lastLoginLatitude ?? this.lastLoginLatitude,
      lastLoginLongitude: lastLoginLongitude ?? this.lastLoginLongitude,
      lastLoginDevice: lastLoginDevice ?? this.lastLoginDevice,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserEntity &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.role == role &&
        other.isActive == isActive &&
        other.lastLoginAt == lastLoginAt &&
        other.lastLoginLocation == lastLoginLocation;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        role.hashCode ^
        isActive.hashCode ^
        (lastLoginAt?.hashCode ?? 0) ^
        (lastLoginLocation?.hashCode ?? 0);
  }
}
