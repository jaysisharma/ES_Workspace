import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

enum BulkDeleteCriteria { tillDate, tillOrderId }

enum DateCompareField { eventDate, createdAt }

class BulkDeleteOrdersScreen extends ConsumerStatefulWidget {
  const BulkDeleteOrdersScreen({super.key});

  @override
  ConsumerState<BulkDeleteOrdersScreen> createState() =>
      _BulkDeleteOrdersScreenState();
}

class _BulkDeleteOrdersScreenState
    extends ConsumerState<BulkDeleteOrdersScreen> {
  BulkDeleteCriteria _criteria = BulkDeleteCriteria.tillDate;
  DateCompareField _dateField = DateCompareField.eventDate;

  DateTime _selectedCutoffDate = DateTime.now();
  String _selectedOrderId = '';
  final TextEditingController _orderIdController = TextEditingController();

  bool _includeArchivedOnly = false;
  OrderStatus? _statusFilter;
  bool _isProcessing = false;

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  List<OrderEntity> _getMatchingOrders(List<OrderEntity> allOrders) {
    if (allOrders.isEmpty) return [];

    final cutoffDay = DateTime(
      _selectedCutoffDate.year,
      _selectedCutoffDate.month,
      _selectedCutoffDate.day,
      23,
      59,
      59,
    );

    OrderEntity? targetOrder;
    if (_criteria == BulkDeleteCriteria.tillOrderId &&
        _selectedOrderId.isNotEmpty) {
      targetOrder = allOrders
          .where((o) => o.id.toLowerCase() == _selectedOrderId.toLowerCase())
          .firstOrNull;
    }

    return allOrders.where((order) {
      // 1. Status Filter
      if (_statusFilter != null && order.status != _statusFilter) {
        return false;
      }

      // 2. Archived Filter
      if (_includeArchivedOnly && !order.isArchived) {
        return false;
      }

      // 3. Criteria Filter
      if (_criteria == BulkDeleteCriteria.tillDate) {
        final orderDate = _dateField == DateCompareField.eventDate
            ? order.eventDate
            : order.createdAt;
        return !orderDate.isAfter(cutoffDay);
      } else {
        // Till Order ID
        if (_selectedOrderId.isEmpty) return false;

        if (targetOrder != null) {
          return !order.createdAt.isAfter(targetOrder.createdAt);
        } else {
          return order.id.toLowerCase() == _selectedOrderId.toLowerCase();
        }
      }
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _executeBulkDelete(List<OrderEntity> ordersToDelete) async {
    if (ordersToDelete.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final ids = ordersToDelete.map((o) => o.id).toList();

      // Chunk in batches of 350 for Firestore operations
      const chunkSize = 350;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
        final chunk = ids.sublist(i, end);

        final batch = firestore.batch();

        for (final id in chunk) {
          batch.delete(firestore.collection('orders').doc(id));
        }

        await batch.commit();

        for (final id in chunk) {
          final events = await firestore
              .collection('events')
              .where('orderId', isEqualTo: id)
              .get();
          for (final doc in events.docs) {
            await doc.reference.delete();
          }

          final items = await firestore
              .collection('order_items')
              .where('orderId', isEqualTo: id)
              .get();
          for (final doc in items.docs) {
            await doc.reference.delete();
          }

          final expenses = await firestore
              .collection('expenses')
              .where('orderId', isEqualTo: id)
              .get();
          for (final doc in expenses.docs) {
            await doc.reference.delete();
          }

          final addRev = await firestore
              .collection('additional_revenue')
              .where('orderId', isEqualTo: id)
              .get();
          for (final doc in addRev.docs) {
            await doc.reference.delete();
          }

          final changeReqs = await firestore
              .collection('change_requests')
              .where('orderId', isEqualTo: id)
              .get();
          for (final doc in changeReqs.docs) {
            await doc.reference.delete();
          }
        }
      }

      ref.invalidate(ordersStreamProvider);
      ref.invalidate(eventsStreamProvider);
      ref.invalidate(allItemsStreamProvider);
      ref.invalidate(allExpensesStreamProvider);
      ref.invalidate(allAdditionalRevenueStreamProvider);
      await ref.read(orderNotifierProvider.notifier).loadOrders();

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully purged ' + ordersToDelete.length.toString() + ' orders and related records.',
            ),
            backgroundColor: const Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting orders: ' + e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showConfirmationSheet(List<OrderEntity> ordersToDelete) {
    final confirmationController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isConfirmed =
                confirmationController.text.trim().toUpperCase() == 'DELETE';

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1a1315) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Permanent Deletion Warning',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'This action cannot be undone',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are about to permanently delete ' +
                              ordersToDelete.length.toString() +
                              ' order(s).',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• All line items, tasks, and quantities will be removed.\n'
                          '• Financial transactions, invoices & payments will be deleted.\n'
                          '• Calendar events and audit logs will be permanently purged.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'To confirm, type "DELETE" below:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2d1c20)
                          : const Color(0xFFfee2e2).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (!isConfirmed || _isProcessing)
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _executeBulkDelete(ordersToDelete);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.red.withValues(
                              alpha: 0.3,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Purge ' +
                                      ordersToDelete.length.toString() +
                                      ' Orders',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final isAdminOrFounder =
        user?.role == UserRole.admin || user?.role == UserRole.founder;

    if (!isAdminOrFounder) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only Administrators & Founders can access Bulk Delete.'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final cardBgColor = isDark ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);

    final ordersAsync = ref.watch(ordersStreamProvider);
    final orderState = ref.watch(orderNotifierProvider);
    final allOrders = (ordersAsync.value ?? orderState.orders);

    final matchingOrders = _getMatchingOrders(allOrders);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0b1319)
          : const Color(0xFFf8fafc),
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: const Text(
          'Bulk Delete Orders',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh Data',
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(ordersStreamProvider);
              ref.invalidate(eventsStreamProvider);
              ref.read(orderNotifierProvider.notifier).loadOrders();
            },
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Purging selected orders & dependencies...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 750;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF26181b)
                                    : const Color(0xFFfef2f2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete_sweep_rounded,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Batch Data Purge Tool',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Safely purge historical orders up to a specific date or order cutoff.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1. Choose Purge Criteria',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  SegmentedButton<BulkDeleteCriteria>(
                                    segments: const [
                                      ButtonSegment(
                                        value: BulkDeleteCriteria.tillDate,
                                        label: Text('Till Date (📅)'),
                                        icon: Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                        ),
                                      ),
                                      ButtonSegment(
                                        value: BulkDeleteCriteria.tillOrderId,
                                        label: Text('Till Order # (🔢)'),
                                        icon: Icon(
                                          Icons.format_list_numbered_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                    selected: {_criteria},
                                    onSelectionChanged: (val) {
                                      setState(() => _criteria = val.first);
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  if (_criteria ==
                                      BulkDeleteCriteria.tillDate) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Compare Date Field:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              DropdownButtonFormField<
                                                DateCompareField
                                              >(
                                                value: _dateField,
                                                decoration: InputDecoration(
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value:
                                                        DateCompareField
                                                            .eventDate,
                                                    child: Text('Event Date'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value:
                                                        DateCompareField
                                                            .createdAt,
                                                    child: Text(
                                                      'Order Creation Date',
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(
                                                      () => _dateField = val,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Purge Cutoff Date:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              OutlinedButton.icon(
                                                style:
                                                    OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 12,
                                                        vertical: 14,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                    ),
                                                onPressed: () async {
                                                  final picked =
                                                      await NepaliDatePickerDialog.show(
                                                        context: context,
                                                        title: 'Select Cutoff Date',
                                                        initialStart: _selectedCutoffDate,
                                                        allowRange: false,
                                                      );
                                                  if (picked != null &&
                                                      picked['start'] != null) {
                                                    setState(() {
                                                      _selectedCutoffDate =
                                                          picked['start']!;
                                                    });
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  formatNepaliDate(
                                                    _selectedCutoffDate,
                                                    'yyyy MMMM dd',
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Select Cutoff Order:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Autocomplete<OrderEntity>(
                                          displayStringForOption: (o) =>
                                              '#' + o.id + ' - ' + o.eventName + ' (' + formatNepaliDate(o.eventDate, 'MMM dd, yyyy') + ')',
                                          optionsBuilder: (textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return allOrders.take(20);
                                            }
                                            final q = textEditingValue.text
                                                .toLowerCase();
                                            return allOrders.where(
                                              (o) =>
                                                  o.id.toLowerCase().contains(
                                                    q,
                                                  ) ||
                                                  o.eventName
                                                      .toLowerCase()
                                                      .contains(q),
                                            );
                                          },
                                          onSelected: (order) {
                                            setState(() {
                                              _selectedOrderId = order.id;
                                              _orderIdController.text =
                                                  order.id;
                                            });
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                controller,
                                                focusNode,
                                                onFieldSubmitted,
                                              ) {
                                                return TextField(
                                                  controller: controller,
                                                  focusNode: focusNode,
                                                  onChanged: (val) {
                                                    setState(
                                                      () => _selectedOrderId =
                                                          val.trim(),
                                                    );
                                                  },
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Search or enter Order ID (e.g. ORD-1002)...',
                                                    prefixIcon: const Icon(
                                                      Icons.search_rounded,
                                                      size: 20,
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 12,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'All orders created on or prior to this order will be selected for purge.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  const Divider(height: 1),
                                  const SizedBox(height: 16),

                                  const Text(
                                    '2. Filter Matching Scope',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilterChip(
                                        label: const Text('All Statuses'),
                                        selected: _statusFilter == null,
                                        onSelected: (_) => setState(
                                          () => _statusFilter = null,
                                        ),
                                      ),
                                      ...OrderStatus.values.map((st) {
                                        final isSel = _statusFilter == st;
                                        return FilterChip(
                                          label: Text(
                                            st.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          selected: isSel,
                                          onSelected: (_) => setState(
                                            () => _statusFilter = isSel
                                                ? null
                                                : st,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Target Only Archived Orders',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Keep active live orders safe and purge only archived orders',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    value: _includeArchivedOnly,
                                    activeTrackColor: primaryColor,
                                    onChanged: (val) => setState(
                                      () => _includeArchivedOnly = val,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '3. Matching Orders Preview (' +
                                          matchingOrders.length.toString() +
                                          ')',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                if (matchingOrders.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _showConfirmationSheet(
                                      matchingOrders,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_forever_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Purge (' +
                                          matchingOrders.length.toString() +
                                          ')',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (matchingOrders.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 44,
                                      color: Color(0xFF10b981),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No Orders Match Current Purge Criteria',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Adjust the date cutoff, order number, or status filters above.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (matchingOrders.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.only(
                          left: isMobile ? 16 : 24,
                          right: isMobile ? 16 : 24,
                          bottom: 100,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final order = matchingOrders[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: borderColor.withValues(alpha: 0.8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '#' + order.id,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                order.eventName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              'Event: ' +
                                                  formatNepaliDate(
                                                    order.eventDate,
                                                    'MMM dd, yyyy',
                                                  ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Created: ' +
                                                  formatNepaliDate(
                                                    order.createdAt,
                                                    'MMM dd, yyyy',
                                                  ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (order.isArchived
                                                      ? Colors.grey
                                                      : primaryColor)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          order.isArchived
                                              ? 'ARCHIVED'
                                              : order.status.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: order.isArchived
                                                ? Colors.grey
                                                : primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rs. ' +
                                            order.totalAmount.toStringAsFixed(
                                              0,
                                            ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }, childCount: matchingOrders.length),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
