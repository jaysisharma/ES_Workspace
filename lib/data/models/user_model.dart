import 'package:order_app/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final email = json['email'] as String? ?? 'unknown@eventflow.pro';
    return UserModel(
      id: json['id'] as String? ?? docId ?? 'unknown',
      name: json['name'] as String? ?? email.split('@').first,
      email: email,
      role: _parseRole(json['role'] as String? ?? 'staff'),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'isActive': isActive,
    };
  }

  static UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'finance':
        return UserRole.finance;
      case 'staff':
        return UserRole.staff;
      case 'founder':
      case 'director':
      case 'ceo':
        return UserRole.founder;
      default:
        return UserRole.staff; // Default fallback
    }
  }

  // Helper to convert from Entity to Model if needed
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      role: entity.role,
      isActive: entity.isActive,
    );
  }
}
