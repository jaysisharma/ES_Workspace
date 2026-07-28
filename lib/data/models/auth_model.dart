import '../../domain/entities/auth_entity.dart';
import '../../domain/entities/user_entity.dart';

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
    if (roleStr == null) return UserRole.staff; // Default fallback
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'founder':
        return UserRole.founder;
      default:
        return UserRole.staff;
    }
  }

  factory AuthModel.fromEntity(AuthEntity entity) {
    return AuthModel(uid: entity.uid, email: entity.email, role: entity.role);
  }
}
