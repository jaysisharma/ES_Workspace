enum UserRole { admin, staff, founder }

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
