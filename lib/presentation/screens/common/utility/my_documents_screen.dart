import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:order_app/presentation/widgets/common/document_action_buttons.dart';

/// Lets the signed-in user view, download and share their own ID documents.
class MyDocumentsScreen extends ConsumerWidget {
  const MyDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentEmployeeProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final owner = profile?.name.trim().isNotEmpty == true ? profile!.name.trim() : 'My';

    final docs = <(String, String?)>[
      ('Citizenship Front', profile?.citizenshipPhotoFrontUrl),
      ('Citizenship Back', profile?.citizenshipPhotoBackUrl),
      ('NIN Card', profile?.ninPhotoUrl),
      ('PAN Card', profile?.panPhotoUrl),
    ].where((d) => d.$2 != null && d.$2!.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My ID Documents',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: docs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No documents uploaded yet.\nAsk administration to upload your citizenship and ID cards.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final (title, source) = docs[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            DocumentActionButtons(
                              source: source!,
                              baseName: '$owner $title',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: _DocumentImage(source: source),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DocumentImage extends StatelessWidget {
  final String source;
  const _DocumentImage({required this.source});

  @override
  Widget build(BuildContext context) {
    const fit = BoxFit.contain;
    final fallback = Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    try {
      if (source.startsWith('data:image')) {
        return Image.memory(base64Decode(source.split(',').last), fit: fit);
      }
      if (source.startsWith('http://') || source.startsWith('https://')) {
        return Image.network(
          source,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      }
      final file = File(source);
      if (file.existsSync()) return Image.file(file, fit: fit);
    } catch (_) {}
    return fallback;
  }
}
