import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/domain/entities/client_entity.dart';
import 'package:order_app/presentation/providers/client_provider.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

// ── Client Screen ──────────────────────────────────────────────────────────────

class ClientScreen extends ConsumerStatefulWidget {
  const ClientScreen({super.key});

  @override
  ConsumerState<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends ConsumerState<ClientScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClientEntity> _filter(List<ClientEntity> clients) {
    if (_query.isEmpty) return clients;
    final q = _query.toLowerCase();
    return clients
        .where(
          (v) =>
              v.name.toLowerCase().contains(q) ||
              v.contactPerson.toLowerCase().contains(q) ||
              v.email.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Form sheet ──────────────────────────────────────────────────────────────
  void _showForm({ClientEntity? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClientFormSheet(
        existing: existing,
        onSave: (client) async {
          final notifier = ref.read(clientNotifierProvider.notifier);
          bool ok;
          if (existing != null) {
            ok = await notifier.updateClient(client);
          } else {
            ok = await notifier.addClient(client);
          }
          if (mounted && !ok) {
            final err = ref.read(clientNotifierProvider).errorMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err ?? 'Operation failed'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // ── Actions menu ────────────────────────────────────────────────────────────
  void _showMenu(ClientEntity client) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _MenuTile(
                icon: Icons.edit_outlined,
                label: 'Edit Client',
                color: colorScheme.primary,
                textColor: colorScheme.onSurface,
                onTap: () {
                  Navigator.pop(context);
                  _showForm(existing: client);
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Client',
                color: Colors.red,
                textColor: colorScheme.onSurface,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(client);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ClientEntity client) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text(
          'Delete Client?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete "${client.name}"? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: labelColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref
                  .read(clientNotifierProvider.notifier)
                  .deleteClient(client.id);
              if (mounted && !ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete client'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(List<ClientEntity> clients) async {
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No clients to export'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final headers = ['Client Name', 'Contact Person', 'Phone', 'Email', 'Notes'];
    final rows = clients.map((c) => [
      c.name,
      c.contactPerson,
      c.phone,
      c.email,
      c.notes,
    ]).toList();

    final fileName = 'Clients_Export_${formatNepaliDate(DateTime.now(), "yyyyMMdd")}.xlsx';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: fileName,
      sheetName: 'Clients',
      title: 'Client Directory List',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final bgColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final inputBg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    final clientState = ref.watch(clientNotifierProvider);
    final displayed = _filter(clientState.clients);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────────
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.95),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        )
                      else if (MediaQuery.of(context).size.width < 768)
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(Icons.menu_rounded, color: textColor),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        'Clients',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (clientState.isLoading)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _exportToExcel(displayed),
                        icon: Icon(
                          Icons.table_chart_outlined,
                          color: primaryColor,
                          size: 26,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: clientState.isLoading ? null : _showForm,
                        icon: Icon(
                          Icons.add_rounded,
                          color: primaryColor,
                          size: 26,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Search ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search client…',
                  hintStyle: TextStyle(
                    color: labelColor.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _query.isEmpty ? labelColor : primaryColor,
                    size: 22,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: labelColor, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),

            // ── Error banner ──────────────────────────────────────────────
            if (clientState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          clientState.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(clientNotifierProvider.notifier).refresh(),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Client List ───────────────────────────────────────────────
            Expanded(
              child: clientState.isLoading && clientState.clients.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : displayed.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 52,
                            color: labelColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'No clients yet'
                                : 'No results for "$_query"',
                            style: TextStyle(color: labelColor, fontSize: 14),
                          ),
                          if (_query.isEmpty) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _showForm,
                              icon: const Icon(Icons.add),
                              label: const Text('Add your first client'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: primaryColor,
                      onRefresh: () =>
                          ref.read(clientNotifierProvider.notifier).refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: displayed.length,
                        itemBuilder: (_, i) => _ClientCard(
                          client: displayed[i],
                          onMenuTap: () => _showMenu(displayed[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────────
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Navigator.canPop(context)) ...[
            const BottomRightBackButton(),
            const SizedBox(width: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'client_fab',
            onPressed: clientState.isLoading ? null : _showForm,
            backgroundColor: primaryColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Client',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client Card ───────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final ClientEntity client;
  final VoidCallback onMenuTap;

  const _ClientCard({required this.client, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    // Name initials for avatar
    final initials = client.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: avatar + name + menu
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  client.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: labelColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.more_vert, color: labelColor, size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _ContactRow(
            icon: Icons.person_outline_rounded,
            text: client.contactPerson.isEmpty ? '—' : client.contactPerson,
            color: primaryColor,
            labelColor: labelColor,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.call_outlined,
            text: client.phone.isEmpty ? '—' : client.phone,
            color: primaryColor,
            labelColor: labelColor,
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            text: client.email.isEmpty ? '—' : client.email,
            color: primaryColor,
            labelColor: labelColor,
          ),

          if (client.notes.isNotEmpty) ...[
            Divider(height: 24, color: borderColor),
            Text(
              client.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color labelColor;

  const _ContactRow({
    required this.icon,
    required this.text,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: labelColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Context Menu Tile ─────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit Bottom Sheet ───────────────────────────────────────────────────

class _ClientFormSheet extends StatefulWidget {
  final ClientEntity? existing;
  final Future<void> Function(ClientEntity) onSave;

  const _ClientFormSheet({this.existing, required this.onSave});

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _personCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _personCtrl = TextEditingController(text: e?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _personCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final client = ClientEntity(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      contactPerson: _personCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );

    await widget.onSave(client);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;
    final inputBg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    InputDecoration fieldDec(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: labelColor, size: 20),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  widget.existing == null ? 'Add Client' : 'Edit Client',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 20),

                _Label('Client Name *', textColor),
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: fieldDec('e.g. ABC Corp', Icons.business_rounded),
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Contact Person', textColor),
                          TextFormField(
                            controller: _personCtrl,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: fieldDec(
                              'e.g. John Doe',
                              Icons.person_outline,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Phone Number', textColor),
                          TextFormField(
                            controller: _phoneCtrl,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: fieldDec(
                              '98XXXXXXXX',
                              Icons.call_outlined,
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _Label('Email Address', textColor),
                TextFormField(
                  controller: _emailCtrl,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: fieldDec(
                    'client@example.com',
                    Icons.mail_outline_rounded,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),

                _Label('Notes', textColor),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration:
                      fieldDec(
                        'Additional details about the client…',
                        Icons.notes_rounded,
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),

                // Save button
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.existing == null
                              ? 'Save Client'
                              : 'Update Client',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
