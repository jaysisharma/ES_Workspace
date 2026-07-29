import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/company_document_entity.dart';
import '../../data/repositories/firestore_company_document_repository.dart';
import '../../data/services/synology_service.dart';
import '../../core/utils/company_pdf_generator.dart';

// ── Repository & Service Providers ───────────────────────────────────────────
final companyDocumentRepoProvider = Provider<FirestoreCompanyDocumentRepository>(
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

  FirestoreCompanyDocumentRepository get _repo => ref.read(companyDocumentRepoProvider);
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
      final filename = 'Company_Details_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final uploadRes = await _synologyService.uploadPdf(
        config: state.synologyConfig,
        fileBytes: pdfBytes,
        filename: filename,
      );

      final synologyPath = uploadRes?['synologyPath'] ?? '/company_docs/$filename';
      final shareUrl = uploadRes?['shareUrl'] ?? '${state.synologyConfig.host}/sharing/$filename';

      final doc = CompanyDocumentEntity(
        id: '',
        title: title.isEmpty ? 'ES Workspace Official Company Profile PDF' : title,
        description: description.isEmpty ? 'Official company presentation & services brochure' : description,
        synologyPath: synologyPath,
        shareUrl: shareUrl,
        fileSize: pdfBytes.length,
        uploadedAt: DateTime.now(),
        uploadedBy: 'Admin',
      );

      await _repo.addDocument(doc);
      await _init();
      state = state.copyWith(successMessage: 'Company PDF generated & uploaded to Synology NAS');
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

      final synologyPath = uploadRes?['synologyPath'] ?? '/company_docs/$filename';
      final shareUrl = uploadRes?['shareUrl'] ?? '${state.synologyConfig.host}/sharing/$filename';

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
      state = state.copyWith(successMessage: 'File successfully uploaded to Synology NAS');
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
    required CompanyDocumentEntity doc,
    required String clientName,
    String? customNote,
  }) async {
    final message = '''
Hello ${clientName.isNotEmpty ? clientName : 'Client'},

Please find attached our official Company Profile & Details document from ES Workspace:

📄 Document: ${doc.title}
${doc.description.isNotEmpty ? '📝 Details: ${doc.description}\n' : ''}
🔗 Synology NAS Download & Sharing Link:
${doc.shareUrl}

If you have any questions or require custom event quotations, please let us know!

Best Regards,
ES Workspace Management Team
''';

    await Share.share(message, subject: 'Company Profile & Details - ES Workspace');
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final companyDocumentNotifierProvider =
    NotifierProvider<CompanyDocumentNotifier, CompanyDocumentState>(
  () => CompanyDocumentNotifier(),
);
