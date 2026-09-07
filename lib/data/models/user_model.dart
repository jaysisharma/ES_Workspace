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
    final clean = roleStr
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
    switch (clean) {
      case 'admin':
        return UserRole.admin;
      case 'director':
      case 'founder':
      case 'ceo':
        return UserRole.director;
      case 'companysecretary':
      case 'secretary':
        return UserRole.companySecretary;
      case 'seniorstaff':
        return UserRole.seniorStaff;
      case 'finance':
        return UserRole.finance;
      case 'staff':
      default:
        return UserRole.staff;
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
