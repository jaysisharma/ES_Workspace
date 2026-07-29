import 'package:flutter/foundation.dart';

@immutable
class CompanyDocumentEntity {
  final String id;
  final String title;
  final String description;
  final String synologyPath;
  final String shareUrl;
  final int fileSize; // Bytes
  final DateTime uploadedAt;
  final String uploadedBy;

  const CompanyDocumentEntity({
    required this.id,
    required this.title,
    this.description = '',
    required this.synologyPath,
    required this.shareUrl,
    this.fileSize = 0,
    required this.uploadedAt,
    this.uploadedBy = 'Admin',
  });

  CompanyDocumentEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? synologyPath,
    String? shareUrl,
    int? fileSize,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return CompanyDocumentEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      synologyPath: synologyPath ?? this.synologyPath,
      shareUrl: shareUrl ?? this.shareUrl,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }
}
