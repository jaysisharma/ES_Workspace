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

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
  });

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
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
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        role.hashCode ^
        isActive.hashCode;
  }
}
