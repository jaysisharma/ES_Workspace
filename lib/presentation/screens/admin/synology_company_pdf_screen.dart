import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/domain/entities/company_document_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/core/utils/company_pdf_generator.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:order_app/core/utils/pdf_export_helper.dart';

class SynologyCompanyPdfScreen extends ConsumerStatefulWidget {
  const SynologyCompanyPdfScreen({super.key});

  @override
  ConsumerState<SynologyCompanyPdfScreen> createState() =>
      _SynologyCompanyPdfScreenState();
}

class _SynologyCompanyPdfScreenState
    extends ConsumerState<SynologyCompanyPdfScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authNotifierProvider);
    final isStaff = authState.user?.role == UserRole.staff;
    final docState = ref.watch(companyDocumentNotifierProvider);
    final synologyConfig = docState.synologyConfig;
    final documents = docState.documents;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text(
          'Company PDF & Synology Sharing',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (!isStaff)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configure Synology NAS',
              onPressed: () => _showSynologyConfigDialog(context, synologyConfig),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(companyDocumentNotifierProvider.notifier).refresh();
            },
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Navigator.canPop(context)) ...[
            const BottomRightBackButton(),
            const SizedBox(width: 12),
          ],
          if (!isStaff)
            FloatingActionButton.extended(
              heroTag: 'synology_company_pdf_fab',
              onPressed: docState.isLoading ? null : () => _showUploadCustomDialog(context),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(companyDocumentNotifierProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Synology Connection Status Card (Admin & Founder Only)
              if (!isStaff) ...[
                _buildSynologyStatusCard(context, synologyConfig),
                const SizedBox(height: 16),
              ],

              // Upload PDF Action Buttons (Admin & Founder Only)
              if (!isStaff) ...[
                Text(
                  'UPLOAD & ADD DOCUMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: docState.isLoading
                        ? null
                        : () => _showUploadCustomDialog(context),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text(
                      'Upload Company PDF File',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Document Roster Header
              Text(
                isStaff
                    ? 'AVAILABLE COMPANY DOCUMENTS & RATE CARDS'
                    : 'MANAGED COMPANY DOCUMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              if (docState.isLoading && documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (documents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 54,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No company details PDF uploaded yet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Company profile files in Synology NAS will appear here for sharing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...documents.map((doc) => _buildDocumentCard(context, doc, isStaff)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSynologyStatusCard(
      BuildContext context, SynologyConfig config) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConfigured = config.isConfigured;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfigured
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfigured
              ? colorScheme.primary.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConfigured ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfigured ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Synology NAS Server',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isConfigured ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isConfigured ? 'CONNECTED' : 'NOT SET',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isConfigured
                      ? 'Host: ${config.host} (${config.destinationFolder})'
                      : 'Configure NAS Host & Account credentials to upload directly to Synology.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showSynologyConfigDialog(context, config),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
      BuildContext context, CompanyDocumentEntity doc, bool isStaff) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizeKb = (doc.fileSize / 1024).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (doc.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        doc.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Synology Path: ${doc.synologyPath} • $sizeKb KB',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isStaff)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDeleteDoc(context, doc),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons: Share to Client, Preview, Copy Link
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showShareToClientDialog(context, doc),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'SHARE VIA APPS / WHATSAPP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _previewPdf(context, doc),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text(
                  'Preview',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.file_download_rounded, size: 18),
                tooltip: 'Download & Save PDF to Device',
                onPressed: () => _downloadAndSavePdf(context, doc),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Synology Link',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: doc.shareUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Synology sharing link copied to clipboard'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _downloadAndSavePdf(BuildContext context, CompanyDocumentEntity doc) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Downloading PDF file…'),
          ],
        ),
        duration: const Duration(seconds: 15),
      ),
    );

    try {
      Uint8List? pdfBytes;
      if (doc.synologyPath.isNotEmpty) {
        final file = File(doc.synologyPath);
        if (await file.exists()) {
          pdfBytes = await file.readAsBytes();
        }
      }

      if (pdfBytes == null && doc.shareUrl.isNotEmpty) {
        if (doc.shareUrl.startsWith('http://') || doc.shareUrl.startsWith('https://')) {
          final res = await http.get(Uri.parse(doc.shareUrl)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            pdfBytes = res.bodyBytes;
          }
        }
      }

      pdfBytes ??= await CompanyPdfGenerator.generateCompanyDetailsPdf(
        companyName: doc.title,
        tagline: doc.description,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final cleanName = '${doc.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
      await PdfExportHelper.exportAndSharePdf(
        context: context,
        pdfBytes: pdfBytes,
        filename: cleanName,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download PDF file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSynologyConfigDialog(
      BuildContext context, SynologyConfig currentConfig) {
    final hostController = TextEditingController(text: currentConfig.host);
    final userController = TextEditingController(text: currentConfig.username);
    final passController = TextEditingController(text: currentConfig.password);
    final folderController = TextEditingController(
        text: currentConfig.destinationFolder.isEmpty
            ? '/company_docs'
            : currentConfig.destinationFolder);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Synology NAS Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'Synology Host / URL',
                  hintText: 'https://synology.mycompany.com:5001',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userController,
                decoration: const InputDecoration(
                  labelText: 'Synology Username',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Synology Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(
                  labelText: 'Shared Folder / Path',
                  hintText: '/company_docs',
                  prefixIcon: Icon(Icons.folder_shared),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newConfig = SynologyConfig(
                host: hostController.text.trim(),
                username: userController.text.trim(),
                password: passController.text.trim(),
                destinationFolder: folderController.text.trim(),
              );
              Navigator.pop(ctx);
              final success = await ref
                  .read(companyDocumentNotifierProvider.notifier)
                  .saveSynologyConfig(newConfig);

              if (ctx.mounted && success) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Synology NAS configuration saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  void _showUploadCustomDialog(BuildContext context) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open file picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    Uint8List? fileBytes = pickedFile.bytes;
    if (fileBytes == null && pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    }

    if (fileBytes == null || !context.mounted) return;

    final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'Company_Document.pdf';
    final titleController = TextEditingController(
        text: filename.replaceAll('.pdf', '').replaceAll('_', ' '));
    final descController =
        TextEditingController(text: 'Official company PDF document');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_file_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Upload PDF to Synology NAS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Document Title',
                  hintText: 'e.g. Company Profile & Package Rates 2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of document contents',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_rounded, size: 16),
            label: const Text('UPLOAD TO SYNOLOGY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(companyDocumentNotifierProvider.notifier)
                  .uploadCustomPdf(
                    fileBytes: fileBytes!,
                    filename: filename,
                    title: titleController.text.trim().isEmpty
                        ? filename
                        : titleController.text.trim(),
                    description: descController.text.trim(),
                  );
              if (ctx.mounted) {
                if (success) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('PDF uploaded to Synology NAS successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to upload PDF to Synology NAS'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showShareToClientDialog(
      BuildContext context, CompanyDocumentEntity doc) {
    final nameController = TextEditingController();
    final customNoteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.share_rounded, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Share Company Profile',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Synology PDF • ${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Optional Recipient Name
                Text(
                  'RECIPIENT NAME (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Client Name / Company Name',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 14),

                // Custom Message / Note
                Text(
                  'CUSTOM MESSAGE / NOTE (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: customNoteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Please check our updated event service details and package rates.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 14),

                // Synology Link Box
                Text(
                  'SYNOLOGY DOWNLOAD & SHARE LINK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: SelectableText(
                    doc.shareUrl,
                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_download_rounded, size: 16),
            label: const Text('Save PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndSavePdf(context, doc);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: doc.shareUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Synology link copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text(
              'SHARE VIA APPS / WHATSAPP',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(companyDocumentNotifierProvider.notifier)
                  .shareDocumentToClient(
                    context: ctx,
                    doc: doc,
                    clientName: nameController.text.trim(),
                    customNote: customNoteController.text.trim(),
                  );
            },
          ),
        ],
      ),
    );
  }

  void _previewPdf(BuildContext context, CompanyDocumentEntity doc) async {
    Uint8List? pdfBytes;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Loading PDF preview…'),
          ],
        ),
        duration: const Duration(seconds: 15),
      ),
    );

    try {
      if (doc.synologyPath.isNotEmpty) {
        final file = File(doc.synologyPath);
        if (await file.exists()) {
          pdfBytes = await file.readAsBytes();
        }
      }

      if (pdfBytes == null && doc.shareUrl.isNotEmpty) {
        if (doc.shareUrl.startsWith('http://') || doc.shareUrl.startsWith('https://')) {
          final res = await http.get(Uri.parse(doc.shareUrl)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            pdfBytes = res.bodyBytes;
          }
        }
      }

      pdfBytes ??= await CompanyPdfGenerator.generateCompanyDetailsPdf(
        companyName: doc.title,
        tagline: doc.description,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfBytes!,
            title: doc.title,
            fileName: '${doc.title.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load PDF preview: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteDoc(BuildContext context, CompanyDocumentEntity doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to remove "${doc.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(companyDocumentNotifierProvider.notifier).deleteDocument(doc.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
