import 'dart:convert';
import 'package:crypto/crypto.dart';

class PassServiceItem {
  final String name;
  final bool isRedeemed;
  final DateTime? redeemedAt;

  const PassServiceItem({
    required this.name,
    this.isRedeemed = false,
    this.redeemedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt?.toIso8601String(),
    };
  }

  factory PassServiceItem.fromMap(Map<String, dynamic> map) {
    return PassServiceItem(
      name: map['name'] ?? '',
      isRedeemed: map['isRedeemed'] ?? false,
      redeemedAt: map['redeemedAt'] != null
          ? DateTime.tryParse(map['redeemedAt'])
          : null,
    );
  }

  PassServiceItem copyWith({
    String? name,
    bool? isRedeemed,
    DateTime? redeemedAt,
  }) {
    return PassServiceItem(
      name: name ?? this.name,
      isRedeemed: isRedeemed ?? this.isRedeemed,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }
}

class EventPassEntity {
  final String id;
  final String clientName;
  final String clientPhone;
  final String eventName;
  final List<PassServiceItem> services;
  final DateTime createdAt;
  final String passSignature;
  final String? companyName;
  final String? photoBase64;

  const EventPassEntity({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.eventName,
    required this.services,
    required this.createdAt,
    required this.passSignature,
    this.companyName,
    this.photoBase64,
  });

  static String generateSignature(String passId, String salt) {
    final bytes = utf8.encode(passId + salt);
    return sha256.convert(bytes).toString();
  }

  static bool verifySignature(String passId, String signature, String salt) {
    return generateSignature(passId, salt) == signature;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'eventName': eventName,
      'services': services.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'passSignature': passSignature,
      'companyName': companyName,
      'photoBase64': photoBase64,
    };
  }

  factory EventPassEntity.fromMap(Map<String, dynamic> map) {
    return EventPassEntity(
      id: map['id'] ?? '',
      clientName: map['clientName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      eventName: map['eventName'] ?? '',
      services: List<PassServiceItem>.from(
        (map['services'] as List<dynamic>? ?? []).map<PassServiceItem>(
          (x) => PassServiceItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      passSignature: map['passSignature'] ?? '',
      companyName: map['companyName'],
      photoBase64: map['photoBase64'],
    );
  }

  EventPassEntity copyWith({
    String? id,
    String? clientName,
    String? clientPhone,
    String? eventName,
    List<PassServiceItem>? services,
    DateTime? createdAt,
    String? passSignature,
    String? companyName,
    String? photoBase64,
  }) {
    return EventPassEntity(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      eventName: eventName ?? this.eventName,
      services: services ?? this.services,
      createdAt: createdAt ?? this.createdAt,
      passSignature: passSignature ?? this.passSignature,
      companyName: companyName ?? this.companyName,
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }
}
