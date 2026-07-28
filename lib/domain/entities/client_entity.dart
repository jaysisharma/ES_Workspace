class ClientEntity {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String notes;

  const ClientEntity({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.notes,
  });

  ClientEntity copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? notes,
  }) {
    return ClientEntity(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientEntity &&
          other.id == id &&
          other.name == name &&
          other.contactPerson == contactPerson &&
          other.phone == phone &&
          other.email == email &&
          other.notes == notes;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      contactPerson.hashCode ^
      phone.hashCode ^
      email.hashCode ^
      notes.hashCode;
}
