import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/company_document_entity.dart';
import 'package:order_app/core/errors/failures.dart';

class FirestoreCompanyDocumentRepository {
  final FirebaseFirestore _firestore;

  FirestoreCompanyDocumentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CompanyDocumentEntity>> getAllDocuments() async {
    try {
      final snapshot = await _firestore
          .collection('company_documents')
          .orderBy('uploadedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch company documents: ${e.toString()}');
    }
  }

  Future<void> addDocument(CompanyDocumentEntity doc) async {
    try {
      final docRef = _firestore.collection('company_documents').doc();
      await docRef.set(_toMap(doc, docRef.id));
    } catch (e) {
      throw ServerException('Failed to add company document: ${e.toString()}');
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _firestore.collection('company_documents').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete company document: ${e.toString()}');
    }
  }

  CompanyDocumentEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CompanyDocumentEntity(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      synologyPath: data['synologyPath'] as String? ?? '',
      shareUrl: data['shareUrl'] as String? ?? '',
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedBy: data['uploadedBy'] as String? ?? 'Admin',
    );
  }

  Map<String, dynamic> _toMap(CompanyDocumentEntity doc, String id) => {
        'id': id,
        'title': doc.title,
        'description': doc.description,
        'synologyPath': doc.synologyPath,
        'shareUrl': doc.shareUrl,
        'fileSize': doc.fileSize,
        'uploadedAt': Timestamp.fromDate(doc.uploadedAt),
        'uploadedBy': doc.uploadedBy,
      };
}
