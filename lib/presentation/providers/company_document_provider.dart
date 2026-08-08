import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/company_document_entity.dart';
import 'package:order_app/data/repositories/firestore_company_document_repository.dart';
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/core/utils/company_pdf_generator.dart';
import 'package:order_app/core/utils/share_helper.dart';

// ── Repository & Service Providers ───────────────────────────────────────────
final companyDocumentRepoProvider =
    Provider<FirestoreCompanyDocumentRepository>(
      (ref) => FirestoreCompanyDocumentRepository(),
    );

final synologyServiceProvider = Provider<SynologyService>(
  (ref) => SynologyService(),
);

// ── State ─────────────────────────────────────────────────────────────────────
class CompanyDocumentState {
  final List<CompanyDocumentEntity> documents;
  final SynologyConfig synologyConfig;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const CompanyDocumentState({
    this.documents = const [],
    this.synologyConfig = const SynologyConfig(),
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  CompanyDocumentState copyWith({
    List<CompanyDocumentEntity>? documents,
    SynologyConfig? synologyConfig,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return CompanyDocumentState(
      documents: documents ?? this.documents,
      synologyConfig: synologyConfig ?? this.synologyConfig,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class CompanyDocumentNotifier extends Notifier<CompanyDocumentState> {
  @override
  CompanyDocumentState build() {
    Future.microtask(_init);
    return const CompanyDocumentState();
  }

  FirestoreCompanyDocumentRepository get _repo =>
      ref.read(companyDocumentRepoProvider);
  SynologyService get _synologyService => ref.read(synologyServiceProvider);

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final config = await _synologyService.getConfig();
      final docs = await _repo.getAllDocuments();
      state = state.copyWith(
        isLoading: false,
        synologyConfig: config,
        documents: docs,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _init();

  Future<bool> saveSynologyConfig(SynologyConfig config) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _synologyService.saveConfig(config);
      state = state.copyWith(
        isLoading: false,
        synologyConfig: config,
        successMessage: 'Synology NAS configuration saved',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> generateAndUploadCompanyPdf({
    required String title,
    required String description,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final pdfBytes = await CompanyPdfGenerator.generateCompanyDetailsPdf();
      final filename =
          'Company_Details_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final uploadRes = await _synologyService.uploadPdf(
        config: state.synologyConfig,
        fileBytes: pdfBytes,
        filename: filename,
      );

      final synologyPath =
          uploadRes?['synologyPath'] ?? '/company_docs/$filename';
      final shareUrl =
          uploadRes?['shareUrl'] ??
          '${state.synologyConfig.host}/sharing/$filename';

      final doc = CompanyDocumentEntity(
        id: '',
        title: title.isEmpty
            ? 'ES Workspace Official Company Profile PDF'
            : title,
        description: description.isEmpty
            ? 'Official company presentation & services brochure'
            : description,
        synologyPath: synologyPath,
        shareUrl: shareUrl,
        fileSize: pdfBytes.length,
        uploadedAt: DateTime.now(),
        uploadedBy: 'Admin',
      );

      await _repo.addDocument(doc);
      await _init();
      state = state.copyWith(
        successMessage: 'Company PDF generated & uploaded to Synology NAS',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> uploadCustomPdf({
    required Uint8List fileBytes,
    required String filename,
    required String title,
    required String description,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final uploadRes = await _synologyService.uploadPdf(
        config: state.synologyConfig,
        fileBytes: fileBytes,
        filename: filename,
      );

      final synologyPath =
          uploadRes?['synologyPath'] ?? '/company_docs/$filename';
      final shareUrl =
          uploadRes?['shareUrl'] ??
          '${state.synologyConfig.host}/sharing/$filename';

      final doc = CompanyDocumentEntity(
        id: '',
        title: title.isEmpty ? filename : title,
        description: description,
        synologyPath: synologyPath,
        shareUrl: shareUrl,
        fileSize: fileBytes.length,
        uploadedAt: DateTime.now(),
        uploadedBy: 'Admin',
      );

      await _repo.addDocument(doc);
      await _init();
      state = state.copyWith(
        successMessage: 'File successfully uploaded to Synology NAS',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteDocument(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deleteDocument(id);
      await _init();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> shareDocumentToClient({
    required BuildContext context,
    required CompanyDocumentEntity doc,
    String? clientName,
    String? customNote,
  }) async {
    final greeting = (clientName != null && clientName.trim().isNotEmpty)
        ? 'Hello ${clientName.trim()},\n\n'
        : 'Namaste!\n\n';
    final note = (customNote != null && customNote.trim().isNotEmpty)
        ? '\n\nNote: ${customNote.trim()}'
        : '';
    final message =
        '''
${greeting}Please find our official Company Profile & Details document from ES Workspace:

📄 ${doc.title}
${doc.description.isNotEmpty ? '📝 ${doc.description}\n' : ''}
🔗 Synology NAS Download & Sharing Link:
${doc.shareUrl}$note

Best Regards,
Event Solution / ES Workspace Team
''';

    await ShareHelper.shareText(
      context: context,
      message: message,
      subject: 'Company Profile - Event Solution',
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final companyDocumentNotifierProvider =
    NotifierProvider<CompanyDocumentNotifier, CompanyDocumentState>(
      () => CompanyDocumentNotifier(),
    );
