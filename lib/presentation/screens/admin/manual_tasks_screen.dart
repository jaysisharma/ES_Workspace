import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/user_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class ManualTasksScreen extends ConsumerWidget {
  const ManualTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final cardColor = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDark
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final bgColor = isDark ? const Color(0xFF0f172a) : const Color(0xFFf8fafc);

    final itemsAsync = ref.watch(allItemsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Assign Tasks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Assign Task'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showAssignTaskSheet(context, ref),
            ),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allItems) {
          final manualTasks = allItems.where((i) => i.isManualTask).toList()
            ..sort((a, b) {
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              return 0;
            });

          if (manualTasks.isEmpty) {
            return _EmptyState(
              labelColor: labelColor,
              onAssign: () => _showAssignTaskSheet(context, ref),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: manualTasks.length,
            itemBuilder: (context, i) => _TaskCard(
              task: manualTasks[i],
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              labelColor: labelColor,
              primaryColor: primaryColor,
              ref: ref,
              onDelete: () => _confirmDelete(context, ref, manualTasks[i]),
              onEdit: () =>
                  _showAssignTaskSheet(context, ref, existing: manualTasks[i]),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    OrderItemEntity task,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "${task.itemName}" assigned to ${task.assignedStaffName ?? "staff"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(orderItemNotifierProvider.notifier)
                  .deleteItem(task.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignTaskSheet(
    BuildContext context,
    WidgetRef ref, {
    OrderItemEntity? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignTaskSheet(existing: existing),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color labelColor;
  final VoidCallback onAssign;
  const _EmptyState({required this.labelColor, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checklist_rtl_rounded,
            size: 72,
            color: labelColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks assigned yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Assign Task" to instruct a staff member.',
            style: TextStyle(
              fontSize: 13,
              color: labelColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Assign Task'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0075db),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAssign,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final OrderItemEntity task;
  final Color cardColor, borderColor, textColor, labelColor, primaryColor;
  final WidgetRef ref;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskCard({
    required this.task,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.ref,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue =
        task.dueDate != null &&
        !task.isCompleted &&
        task.dueDate!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue ? Colors.red.shade300 : borderColor,
          width: overdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => ref
                  .read(orderItemNotifierProvider.notifier)
                  .toggleCompletion(task),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: task.isCompleted ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: task.isCompleted ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.itemName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted ? labelColor : textColor,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.specification.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.specification,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (task.assignedStaffName != null)
                        _Chip(
                          icon: Icons.person_outline_rounded,
                          label: task.assignedStaffName!,
                          color: primaryColor,
                        ),
                      if (task.dueDate != null)
                        _Chip(
                          icon: Icons.event_outlined,
                          label: DateFormat('d MMM yyyy').format(task.dueDate!),
                          color: overdue ? Colors.red : Colors.orange,
                        ),
                      _Chip(
                        icon: task.isCompleted
                            ? Icons.check_circle_outline
                            : Icons.schedule_rounded,
                        label: task.isCompleted ? 'Done' : 'Pending',
                        color: task.isCompleted ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignTaskSheet extends ConsumerStatefulWidget {
  final OrderItemEntity? existing;
  const _AssignTaskSheet({this.existing});

  @override
  ConsumerState<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends ConsumerState<_AssignTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _searchCtrl;

  final Map<String, UserEntity> _selectedStaffMap = {};
  DateTime? _dueDate;
  bool _saving = false;
  String _staffSearch = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.itemName ?? '');
    _descCtrl = TextEditingController(text: e?.specification ?? '');
    _searchCtrl = TextEditingController();
    _dueDate = e?.dueDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);

    final allUsers = ref.watch(userNotifierProvider).users;
    final staffList = allUsers
        .where(
          (u) =>
              u.role == UserRole.staff &&
              u.isActive &&
              (u.name.toLowerCase().contains(_staffSearch.toLowerCase()) ||
                  u.email.toLowerCase().contains(_staffSearch.toLowerCase())),
        )
        .toList();

    // Pre-select existing assignment on edit
    if (_selectedStaffMap.isEmpty && widget.existing?.assignedStaffId != null) {
      try {
        final existingStaff = allUsers.firstWhere(
          (u) => u.id == widget.existing!.assignedStaffId,
        );
        _selectedStaffMap[existingStaff.id] = existingStaff;
      } catch (_) {}
    }

    final isEdit = widget.existing != null;
    final activeStaffList = allUsers
        .where((u) => u.role == UserRole.staff && u.isActive)
        .toList();
    final allSelected = activeStaffList.isNotEmpty &&
        _selectedStaffMap.length == activeStaffList.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_ind_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? 'Edit Task' : 'Assign Task to Staff',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Task Title *',
                hintText: 'e.g. Set up stage lighting',
                prefixIcon: const Icon(Icons.task_alt_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Instructions / Details',
                hintText: 'Provide step-by-step details or notes…',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  isEdit
                      ? 'Assigned To'
                      : 'Assign To (${_selectedStaffMap.length} selected)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!isEdit && activeStaffList.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      allSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                    label: Text(
                      allSelected ? 'Deselect All' : 'Select All (${activeStaffList.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedStaffMap.clear();
                        } else {
                          for (final u in activeStaffList) {
                            _selectedStaffMap[u.id] = u;
                          }
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_selectedStaffMap.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selectedStaffMap.values.map((staff) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: primaryColor,
                      child: Text(
                        staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text(staff.name, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () {
                      setState(() => _selectedStaffMap.remove(staff.id));
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Filter staff by name or email…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() => _staffSearch = v),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFe2e8f0),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: staffList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No staff found')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: staffList.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (ctx, i) {
                        final staff = staffList[i];
                        final selected = _selectedStaffMap.containsKey(staff.id);
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: selected
                                ? primaryColor
                                : primaryColor.withValues(alpha: 0.15),
                            child: Text(
                              staff.name.isNotEmpty
                                  ? staff.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: selected ? Colors.white : primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            staff.name,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            staff.email,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isEdit
                              ? (selected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    )
                                  : null)
                              : Checkbox(
                                  value: selected,
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedStaffMap[staff.id] = staff;
                                      } else {
                                        _selectedStaffMap.remove(staff.id);
                                      }
                                    });
                                  },
                                ),
                          onTap: () {
                            setState(() {
                              if (isEdit) {
                                _selectedStaffMap.clear();
                                _selectedStaffMap[staff.id] = staff;
                              } else {
                                if (selected) {
                                  _selectedStaffMap.remove(staff.id);
                                } else {
                                  _selectedStaffMap[staff.id] = staff;
                                }
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _dueDate ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFe2e8f0),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _dueDate == null
                          ? 'Set Due Date (optional)'
                          : 'Due: ${DateFormat('d MMM yyyy').format(_dueDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _dueDate == null ? Colors.grey : null,
                      ),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isEdit
                      ? 'Save Changes'
                      : (_selectedStaffMap.length > 1
                          ? 'Assign to ${_selectedStaffMap.length} Staff Members'
                          : 'Assign Task'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : () => _save(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStaffMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one staff member')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final currentUser = ref.read(authNotifierProvider).user;
      final notifier = ref.read(orderItemNotifierProvider.notifier);

      if (widget.existing != null) {
        final singleStaff = _selectedStaffMap.values.first;
        final updated = widget.existing!.copyWith(
          itemName: _titleCtrl.text.trim(),
          specification: _descCtrl.text.trim(),
          assignedStaffId: singleStaff.id,
          assignedStaffName: singleStaff.name,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
        );
        await notifier.updateItem(updated);
      } else {
        // Create an individual task instance for each selected staff member
        for (final staff in _selectedStaffMap.values) {
          final task = OrderItemEntity(
            id: const Uuid().v4(),
            orderId: 'manual',
            itemName: _titleCtrl.text.trim(),
            specification: _descCtrl.text.trim(),
            quantity: 1,
            unit: 'task',
            days: 1,
            vendor: '',
            billingType: 'event',
            assignedStaffId: staff.id,
            assignedStaffName: staff.name,
            dueDate: _dueDate,
            createdBy: currentUser?.id,
          );
          await notifier.addItem(task, reload: false);

          // Send in-app notification to this staff member
          await ref
              .read(notificationNotifierProvider.notifier)
              .addNotification(
                NotificationEntity(
                  id: const Uuid().v4(),
                  title: 'New Task Assigned',
                  description: 'You have been assigned: "${task.itemName}"',
                  timestamp: DateTime.now(),
                  type: 'task',
                  relatedId: task.id,
                  targetRole: 'staff',
                  targetUserId: staff.id,
                ),
              );
          FcmSender.sendToUser(
            userId: staff.id,
            title: 'New Task Assigned',
            body: 'You have been assigned: "${task.itemName}"',
          );
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        final count = _selectedStaffMap.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'Task updated!'
                  : (count > 1
                      ? 'Task assigned to $count staff members'
                      : 'Task assigned to ${_selectedStaffMap.values.first.name}'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
