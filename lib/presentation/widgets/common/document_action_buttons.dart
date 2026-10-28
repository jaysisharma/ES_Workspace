import 'package:flutter/material.dart';
import 'package:order_app/core/utils/document_file_helper.dart';

/// Compact Download + Share buttons for an uploaded document photo.
class DocumentActionButtons extends StatefulWidget {
  final String source;
  final String baseName;

  const DocumentActionButtons({
    super.key,
    required this.source,
    required this.baseName,
  });

  @override
  State<DocumentActionButtons> createState() => _DocumentActionButtonsState();
}

class _DocumentActionButtonsState extends State<DocumentActionButtons> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(BuildContext, {required String source, required String baseName}) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(context, source: widget.source, baseName: widget.baseName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.download_rounded, size: 18),
          tooltip: 'Download',
          visualDensity: VisualDensity.compact,
          onPressed: () => _run(DocumentFileHelper.download),
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded, size: 18),
          tooltip: 'Share',
          visualDensity: VisualDensity.compact,
          onPressed: () => _run(DocumentFileHelper.share),
        ),
      ],
    );
  }
}
