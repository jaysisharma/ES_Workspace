import 'package:order_app/domain/entities/auth_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class AuthModel extends AuthEntity {
  const AuthModel({
    required super.uid,
    required super.email,
    required super.role,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      role: _parseRole(json['role'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {'uid': uid, 'email': email, 'role': role.name};
  }

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.staff;
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

  factory AuthModel.fromEntity(AuthEntity entity) {
    return AuthModel(uid: entity.uid, email: entity.email, role: entity.role);
  }
}
