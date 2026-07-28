import 'user_entity.dart';

class AuthEntity {
  final String uid;
  final String email;
  final UserRole role;

  const AuthEntity({
    required this.uid,
    required this.email,
    required this.role,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthEntity &&
        other.uid == uid &&
        other.email == email &&
        other.role == role;
  }

  @override
  int get hashCode => uid.hashCode ^ email.hashCode ^ role.hashCode;
}
