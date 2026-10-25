import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.isActive = true,
    super.lastLoginAt,
    super.lastLoginLocation,
    super.lastLoginLatitude,
    super.lastLoginLongitude,
    super.lastLoginDevice,
    super.lastLoginIp,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final email = json['email'] as String? ?? 'unknown@eventflow.pro';
    DateTime? parsedLastLogin;
    if (json['lastLoginAt'] is Timestamp) {
      parsedLastLogin = (json['lastLoginAt'] as Timestamp).toDate();
    } else if (json['lastLoginAt'] is String) {
      parsedLastLogin = DateTime.tryParse(json['lastLoginAt']);
    }

    return UserModel(
      id: json['id'] as String? ?? docId ?? 'unknown',
      name: json['name'] as String? ?? email.split('@').first,
      email: email,
      role: _parseRole(json['role'] as String? ?? 'staff'),
      isActive: json['isActive'] as bool? ?? true,
      lastLoginAt: parsedLastLogin,
      lastLoginLocation: json['lastLoginLocation'] as String?,
      lastLoginLatitude: (json['lastLoginLatitude'] as num?)?.toDouble(),
      lastLoginLongitude: (json['lastLoginLongitude'] as num?)?.toDouble(),
      lastLoginDevice: json['lastLoginDevice'] as String?,
      lastLoginIp: json['lastLoginIp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'isActive': isActive,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'lastLoginLocation': lastLoginLocation,
      'lastLoginLatitude': lastLoginLatitude,
      'lastLoginLongitude': lastLoginLongitude,
      'lastLoginDevice': lastLoginDevice,
      'lastLoginIp': lastLoginIp,
    };
  }

  static UserRole _parseRole(String roleStr) {
    final clean = roleStr
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
    switch (clean) {
      case 'superadmin':
        return UserRole.superAdmin;
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
      lastLoginAt: entity.lastLoginAt,
      lastLoginLocation: entity.lastLoginLocation,
      lastLoginLatitude: entity.lastLoginLatitude,
      lastLoginLongitude: entity.lastLoginLongitude,
      lastLoginDevice: entity.lastLoginDevice,
      lastLoginIp: entity.lastLoginIp,
    );
  }
}
