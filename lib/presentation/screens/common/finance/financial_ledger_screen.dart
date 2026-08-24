import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/vendor_provider.dart';
import 'package:order_app/presentation/providers/client_provider.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';

enum LedgerPartyFilter { all, client, vendor }

enum LedgerPerspective { combined, client, vendor }

class FinancialLedgerScreen extends ConsumerStatefulWidget {
  const FinancialLedgerScreen({super.key});

  @override
  ConsumerState<FinancialLedgerScreen> createState() =>
      _FinancialLedgerScreenState();
}

class _FinancialLedgerScreenState extends ConsumerState<FinancialLedgerScreen> {
  String? _selectedName;
  String _searchQuery = '';
  LedgerPartyFilter _partyFilter = LedgerPartyFilter.all;
  LedgerPerspective _perspective = LedgerPerspective.combined;

  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final vendorsAsync = ref.watch(vendorNotifierProvider);
    final clientsAsync = ref.watch(clientNotifierProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final allExpensesAsync = ref.watch(allExpensesStreamProvider);
    final allAdditionalRevenueAsync = ref.watch(
      allAdditionalRevenueStreamProvider,
    );
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    final ordersRaw = ordersAsync.value ?? [];
    final allItemsRaw = allItemsAsync.value ?? [];
    final allExpensesRaw = allExpensesAsync.value ?? [];

    // Collect distinct client and vendor names across all models & transactions
    final clientNamesSet = <String>{
      ...clientsAsync.clients
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty),
      ...ordersRaw.map((o) => o.client.trim()).where((n) => n.isNotEmpty),
    };

    final vendorNamesSet = <String>{
      ...vendorsAsync.vendors
          .map((v) => v.name.trim())
          .where((n) => n.isNotEmpty),
      ...allItemsRaw.map((i) => i.vendor.trim()).where((n) => n.isNotEmpty),
      ...allExpensesRaw
          .map((e) => (e.vendorName ?? '').trim())
          .where((n) => n.isNotEmpty),
    };

    final combinedNames = <String>{
      ...clientNamesSet,
      ...vendorNamesSet,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Filter available names according to current party tab filter
    final availableNames = combinedNames.where((name) {
      if (_partyFilter == LedgerPartyFilter.client) {
        return clientNamesSet.contains(name);
      }
      if (_partyFilter == LedgerPartyFilter.vendor) {
        return vendorNamesSet.contains(name);
      }
      return true;
    }).toList();

    final filteredNames = availableNames
        .where(
          (name) =>
              name.toLowerCase().contains(_searchQuery.trim().toLowerCase()),
        )
        .toList();

    final isSelectedClient =
        _selectedName != null && clientNamesSet.contains(_selectedName!.trim());
    final isSelectedVendor =
        _selectedName != null && vendorNamesSet.contains(_selectedName!.trim());
    final isDualRole = isSelectedClient && isSelectedVendor;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: const Text(
          'Financial Ledger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _selectedDateRange != null
                  ? Icons.filter_alt_rounded
                  : Icons.date_range_outlined,
              color: _selectedDateRange != null ? colorScheme.primary : null,
            ),
            tooltip: 'Filter Date Range',
            onPressed: () async {
              final picked = await NepaliDatePickerDialog.show(
                context: context,
                title: 'Filter Ledger Date Range',
                initialStart: _selectedDateRange?.start ?? DateTime.now(),
                initialEnd: _selectedDateRange?.end ?? DateTime.now(),
                allowRange: true,
              );
              if (picked != null && picked['start'] != null) {
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: picked['start']!,
                    end: picked['end'] ?? picked['start']!,
                  );
                });
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            tooltip: 'More actions',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'date_range':
                  final picked = await NepaliDatePickerDialog.show(
                    context: context,
                    title: 'Filter Ledger Date Range',
                    initialStart: _selectedDateRange?.start ?? DateTime.now(),
                    initialEnd: _selectedDateRange?.end ?? DateTime.now(),
                    allowRange: true,
                  );
                  if (picked != null && picked['start'] != null) {
                    setState(() {
                      _selectedDateRange = DateTimeRange(
                        start: picked['start']!,
                        end: picked['end'] ?? picked['start']!,
                      );
                    });
                  }
                  break;
                case 'clear_date':
                  setState(() => _selectedDateRange = null);
                  break;
                case 'reset_entity':
                  setState(() {
                    _selectedName = null;
                    _searchQuery = '';
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date_range',
                child: Row(
                  children: [
                    Icon(Icons.date_range_outlined, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Filter Date Range (BS)',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (_selectedDateRange != null) ...[
                const PopupMenuItem(
                  value: 'clear_date',
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_off_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Clear Date Filter',
                        style: TextStyle(fontSize: 13.5, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedName != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reset_entity',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 18,
                        color: Color(0xFF0075db),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Choose Different Entity',
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersStreamProvider);
          ref.invalidate(allItemsStreamProvider);
          ref.invalidate(allExpensesStreamProvider);
          ref.invalidate(allAdditionalRevenueStreamProvider);
          ref.invalidate(vendorNotifierProvider);
          ref.invalidate(clientNotifierProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── 1. Party Filter & Search Controls ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Filter Bar: All | Clients | Vendors
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          FilterChip(
                            selected: _partyFilter == LedgerPartyFilter.all,
                            avatar: const Icon(
                              Icons.people_alt_outlined,
                              size: 15,
                            ),
                            label: Text(
                              'All Entities (${combinedNames.length})',
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _partyFilter = LedgerPartyFilter.all;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: _partyFilter == LedgerPartyFilter.client,
                            avatar: const Icon(Icons.person_outline, size: 15),
                            label: Text('Clients (${clientNamesSet.length})'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _partyFilter = LedgerPartyFilter.client;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: _partyFilter == LedgerPartyFilter.vendor,
                            avatar: const Icon(
                              Icons.business_outlined,
                              size: 15,
                            ),
                            label: Text('Vendors (${vendorNamesSet.length})'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _partyFilter = LedgerPartyFilter.vendor;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Search / Filter Field
                    TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: _selectedName == null
                            ? 'Search by name or company...'
                            : 'Search events/orders for ${_selectedName}...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() {
                                  _searchQuery = '';
                                }),
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Dropdown Autocomplete results when searching or picking an entity
                    if (_selectedName == null || _searchQuery.isNotEmpty) ...[
                      if (filteredNames.isNotEmpty && _searchQuery.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 240),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: filteredNames.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: colorScheme.outline.withValues(alpha: 0.1),
                              ),
                              itemBuilder: (context, index) {
                              final name = filteredNames[index];
                              final isC = clientNamesSet.contains(name);
                              final isV = vendorNamesSet.contains(name);
                              final isBoth = isC && isV;

                              return ListTile(
                                dense: true,
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBoth)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.purple.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.sync_alt_rounded,
                                              size: 11,
                                              color: Colors.purple,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Client & Vendor',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isC)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0075db,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Client',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0075db),
                                          ),
                                        ),
                                      )
                                    else if (isV)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Vendor',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16),
                                  ],
                                ),
                                onTap: () => setState(() {
                                  _selectedName = name;
                                  _searchQuery = '';
                                  _perspective = LedgerPerspective.combined;
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── 2. Selected Entity Header & Perspective Filter ──
              if (_selectedName != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              child: Text(
                                _selectedName!.isNotEmpty
                                    ? _selectedName![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (isDualRole)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Dual Role: Client & Vendor',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        )
                                      else if (isSelectedClient)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF0075db,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Party: Client',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0075db),
                                            ),
                                          ),
                                        )
                                      else if (isSelectedVendor)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Party: Vendor',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 20,
                              ),
                              tooltip: 'Switch Entity',
                              onPressed: () => setState(() {
                                _selectedName = null;
                                _searchQuery = '';
                              }),
                            ),
                          ],
                        ),
                        if (isDualRole ||
                            (isSelectedClient && isSelectedVendor)) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Text(
                            'Select Ledger Perspective:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Combined (Net Position)'),
                                  avatar: const Icon(Icons.sync_alt, size: 14),
                                  selected:
                                      _perspective ==
                                      LedgerPerspective.combined,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(
                                        () => _perspective =
                                            LedgerPerspective.combined,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Client (Receivables)'),
                                  avatar: const Icon(
                                    Icons.person_outline,
                                    size: 14,
                                  ),
                                  selected:
                                      _perspective == LedgerPerspective.client,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(
                                        () => _perspective =
                                            LedgerPerspective.client,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Vendor (Payables)'),
                                  avatar: const Icon(
                                    Icons.business_outlined,
                                    size: 14,
                                  ),
                                  selected:
                                      _perspective == LedgerPerspective.vendor,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(
                                        () => _perspective =
                                            LedgerPerspective.vendor,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (_selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Period: ${formatNepaliDate(_selectedDateRange!.start, 'MMM dd, yyyy')} - ${formatNepaliDate(_selectedDateRange!.end, 'MMM dd, yyyy')}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () =>
                              setState(() => _selectedDateRange = null),
                          child: const Icon(Icons.close, size: 15),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              _selectedName == null
                  ? _buildEmptyState(
                      'Select an entity or search above to generate the statement',
                    )
                  : ordersAsync.when(
                      data: (ordersRaw) {
                        final orders = ordersRaw.cast<OrderEntity>();
                        return allItemsAsync.when(
                          data: (allItems) {
                            return allExpensesAsync.when(
                              data: (allExpenses) {
                                return allAdditionalRevenueAsync.when(
                                  data: (allManualRevenues) {
                                    // ── FILTERING BASED ON ROLE & PERSPECTIVE ──
                                    final bool includeRevenue =
                                        _perspective ==
                                            LedgerPerspective.combined ||
                                        _perspective ==
                                            LedgerPerspective.client;

                                    final bool includeExpense =
                                        _perspective ==
                                            LedgerPerspective.combined ||
                                        _perspective ==
                                            LedgerPerspective.vendor;

                                    // 1. Client orders (Revenue)
                                    final revenueOrders = includeRevenue
                                        ? orders.where((o) {
                                            final dateMatch =
                                                _selectedDateRange == null ||
                                                (o.eventDate.isAfter(
                                                      _selectedDateRange!.start
                                                          .subtract(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ) &&
                                                    o.eventDate.isBefore(
                                                      _selectedDateRange!.end
                                                          .add(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ));
                                            return o.client == _selectedName &&
                                                dateMatch &&
                                                o.status != OrderStatus.draft;
                                          }).toList()
                                        : <OrderEntity>[];

                                    final revenueOrderIds = revenueOrders
                                        .map((o) => o.id)
                                        .toSet();

                                    final revenueItems = includeRevenue
                                        ? allItems
                                              .where(
                                                (i) => revenueOrderIds.contains(
                                                  i.orderId,
                                                ),
                                              )
                                              .toList()
                                        : <OrderItemEntity>[];
                                    final revenueManual = includeRevenue
                                        ? allManualRevenues
                                              .where(
                                                (r) => revenueOrderIds.contains(
                                                  r.orderId,
                                                ),
                                              )
                                              .toList()
                                        : <ExpenseEntity>[];

                                    // 2. Vendor items & expenses
                                    final expenseItems = includeExpense
                                        ? allItems.where((i) {
                                            final order = orders.firstWhere(
                                              (o) => o.id == i.orderId,
                                              orElse: () => orders.first,
                                            );
                                            final dateMatch =
                                                _selectedDateRange == null ||
                                                (order.eventDate.isAfter(
                                                      _selectedDateRange!.start
                                                          .subtract(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ) &&
                                                    order.eventDate.isBefore(
                                                      _selectedDateRange!.end
                                                          .add(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ));
                                            return i.vendor == _selectedName &&
                                                dateMatch;
                                          }).toList()
                                        : <OrderItemEntity>[];

                                    final expenseManual = includeExpense
                                        ? allExpenses.where((e) {
                                            final dateMatch =
                                                _selectedDateRange == null ||
                                                (e.createdAt.isAfter(
                                                      _selectedDateRange!.start
                                                          .subtract(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ) &&
                                                    e.createdAt.isBefore(
                                                      _selectedDateRange!.end
                                                          .add(
                                                            const Duration(
                                                              days: 1,
                                                            ),
                                                          ),
                                                    ));
                                            return e.vendorName ==
                                                    _selectedName &&
                                                dateMatch;
                                          }).toList()
                                        : <ExpenseEntity>[];

                                    if (revenueOrders.isEmpty &&
                                        expenseItems.isEmpty &&
                                        expenseManual.isEmpty) {
                                      return _buildEmptyState(
                                        'No financial transactions found for ${_selectedName} in this view / period',
                                      );
                                    }

                                    // ── TOTALS ──
                                    final totalRevenue = revenueOrders.fold(
                                      0.0,
                                      (sum, o) => sum + o.totalAmount,
                                    );
                                    final totalExpenses =
                                        expenseItems.fold(
                                          0.0,
                                          (sum, i) => sum + i.vendorAmount,
                                        ) +
                                        expenseManual.fold(
                                          0.0,
                                          (sum, e) => sum + e.amount,
                                        );

                                    final netBalance =
                                        totalRevenue - totalExpenses;

                                    // Related Order IDs
                                    final filteredRelatedOrderIds =
                                        {
                                          ...revenueOrderIds,
                                          ...expenseItems.map((i) => i.orderId),
                                          ...expenseManual.map(
                                            (e) => e.orderId,
                                          ),
                                        }.where((id) {
                                          if (_searchQuery.isEmpty) return true;
                                          final order = orders.firstWhere(
                                            (o) => o.id == id,
                                            orElse: () => orders.first,
                                          );
                                          final query = _searchQuery
                                              .toLowerCase();
                                          return order.eventName
                                                  .toLowerCase()
                                                  .contains(query) ||
                                              order.id.toLowerCase().contains(
                                                query,
                                              );
                                        }).toList();

                                    final ledgerEntries = _collectLedgerEntries(
                                      orders: orders,
                                      revenueItems: revenueItems,
                                      revenueManual: revenueManual,
                                      expenseItems: expenseItems,
                                      expenseManual: expenseManual,
                                    );

                                    final periodText =
                                        _selectedDateRange != null
                                        ? '${formatNepaliDate(_selectedDateRange!.start, "MMM dd, yyyy")} - ${formatNepaliDate(_selectedDateRange!.end, "MMM dd, yyyy")}'
                                        : 'All Time';

                                    final perspectiveTitle =
                                        _perspective ==
                                            LedgerPerspective.combined
                                        ? 'Combined Statement'
                                        : _perspective ==
                                              LedgerPerspective.client
                                        ? 'Client Receivables'
                                        : 'Vendor Payables';

                                    return Column(
                                      children: [
                                        _buildNetSummaryBanner(
                                          rev: totalRevenue,
                                          exp: totalExpenses,
                                          net: netBalance,
                                          currency: currencyLabel,
                                          cs: colorScheme,
                                          perspective: _perspective,
                                          onExportExcel: () => _exportLedgerToExcel(
                                            name:
                                                '${_selectedName!} ($perspectiveTitle)',
                                            totalRevenue: totalRevenue,
                                            totalExpenses: totalExpenses,
                                            entries: ledgerEntries,
                                          ),
                                          onExportPdf: () => _exportLedgerToPdf(
                                            name:
                                                '${_selectedName!} ($perspectiveTitle)',
                                            periodText: periodText,
                                            totalRevenue: totalRevenue,
                                            totalExpenses: totalExpenses,
                                            netBalance: netBalance,
                                            entries: ledgerEntries,
                                          ),
                                        ),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(16),
                                          itemCount:
                                              filteredRelatedOrderIds.length,
                                          itemBuilder: (context, index) {
                                            final orderId =
                                                filteredRelatedOrderIds
                                                    .elementAt(index);
                                            final order = orders.firstWhere(
                                              (o) => o.id == orderId,
                                            );

                                            final isClient =
                                                order.client == _selectedName;
                                            final orderRevenueItems =
                                                isClient && includeRevenue
                                                ? revenueItems
                                                      .where(
                                                        (i) =>
                                                            i.orderId ==
                                                            orderId,
                                                      )
                                                      .toList()
                                                : <OrderItemEntity>[];
                                            final orderRevenueManual =
                                                isClient && includeRevenue
                                                ? revenueManual
                                                      .where(
                                                        (r) =>
                                                            r.orderId ==
                                                            orderId,
                                                      )
                                                      .toList()
                                                : <ExpenseEntity>[];

                                            final orderExpenseItems =
                                                includeExpense
                                                ? expenseItems
                                                      .where(
                                                        (i) =>
                                                            i.orderId ==
                                                            orderId,
                                                      )
                                                      .toList()
                                                : <OrderItemEntity>[];
                                            final orderExpenseManual =
                                                includeExpense
                                                ? expenseManual
                                                      .where(
                                                        (e) =>
                                                            e.orderId ==
                                                            orderId,
                                                      )
                                                      .toList()
                                                : <ExpenseEntity>[];

                                            return _buildOrderGroup(
                                              context,
                                              order,
                                              orderRevenueItems,
                                              orderRevenueManual,
                                              orderExpenseItems,
                                              orderExpenseManual,
                                              currencyLabel,
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (e, _) => Center(
                                    child: Text(
                                      'Error loading manual revenue: $e',
                                    ),
                                  ),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Center(
                                child: Text('Error loading expenses: $e'),
                              ),
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('Error loading items: $e')),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('Error loading orders: $e')),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _collectLedgerEntries({
    required List<OrderEntity> orders,
    required List<OrderItemEntity> revenueItems,
    required List<ExpenseEntity> revenueManual,
    required List<OrderItemEntity> expenseItems,
    required List<ExpenseEntity> expenseManual,
  }) {
    final List<Map<String, dynamic>> entries = [];

    for (final item in revenueItems) {
      final o = orders.firstWhere(
        (ord) => ord.id == item.orderId,
        orElse: () => orders.first,
      );
      entries.add({
        'date': o.eventDate,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Client Revenue',
        'description': '${item.itemName} (${item.quantity} ${item.unit})',
        'qty': item.quantity,
        'unit': item.unit,
        'days': item.days,
        'credit': item.amount,
        'debit': 0.0,
      });
    }

    for (final rev in revenueManual) {
      final o = orders.firstWhere(
        (ord) => ord.id == rev.orderId,
        orElse: () => orders.first,
      );
      entries.add({
        'date': rev.createdAt,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Additional Revenue',
        'description': rev.description.isNotEmpty
            ? rev.description
            : rev.category,
        'qty': rev.quantity,
        'unit': rev.unit,
        'days': rev.days,
        'credit': rev.amount,
        'debit': 0.0,
      });
    }

    for (final item in expenseItems) {
      final o = orders.firstWhere(
        (ord) => ord.id == item.orderId,
        orElse: () => orders.first,
      );
      entries.add({
        'date': o.eventDate,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Vendor Expense',
        'description': '${item.itemName} (${item.quantity} ${item.unit})',
        'qty': item.quantity,
        'unit': item.unit,
        'days': item.days,
        'credit': 0.0,
        'debit': item.vendorAmount,
      });
    }

    for (final exp in expenseManual) {
      final o = orders.firstWhere(
        (ord) => ord.id == exp.orderId,
        orElse: () => orders.first,
      );
      entries.add({
        'date': exp.createdAt,
        'orderId': exp.orderId,
        'eventName': o.eventName,
        'category': 'Manual Expense',
        'description': exp.description.isNotEmpty
            ? exp.description
            : exp.category,
        'qty': exp.quantity,
        'unit': exp.unit,
        'days': exp.days,
        'credit': 0.0,
        'debit': exp.amount,
      });
    }

    entries.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    return entries;
  }

  Future<void> _exportLedgerToExcel({
    required String name,
    required double totalRevenue,
    required double totalExpenses,
    required List<Map<String, dynamic>> entries,
  }) async {
    final headers = [
      'Date',
      'Order ID',
      'Event Name',
      'Category',
      'Description / Item',
      'Qty',
      'Unit',
      'Days',
      'Credit Revenue (NPR)',
      'Debit Expense (NPR)',
    ];

    final rows = entries.map((e) {
      final dateStr = formatNepaliDate(e['date'] as DateTime, 'yyyy-MM-dd');
      return [
        dateStr,
        e['orderId'] ?? '-',
        e['eventName'] ?? '-',
        e['category'] ?? '-',
        e['description'] ?? '-',
        e['qty'] ?? 1,
        e['unit'] ?? 'Pcs',
        e['days'] ?? 1,
        (e['credit'] as num).toDouble() > 0
            ? (e['credit'] as num).toDouble()
            : 0.0,
        (e['debit'] as num).toDouble() > 0
            ? (e['debit'] as num).toDouble()
            : 0.0,
      ];
    }).toList();

    rows.add([
      'TOTAL STATEMENT',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      totalRevenue,
      totalExpenses,
    ]);

    final cleanEntityName = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: 'Ledger_$cleanEntityName.xlsx',
      sheetName: 'Ledger Statement',
      title: 'Financial Ledger Statement - $name',
    );
  }

  Future<void> _exportLedgerToPdf({
    required String name,
    required String periodText,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    required List<Map<String, dynamic>> entries,
  }) async {
    final pdfBytes = await OrderPdfService.generateFinancialLedgerPdf(
      entityName: name,
      periodText: periodText,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netBalance: netBalance,
      ledgerEntries: entries,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      SlidePageRoute(
        page: PdfPreviewScreen(
          title: 'Financial Ledger - $name',
          fileName: 'Ledger_${name.replaceAll(' ', '_')}.pdf',
          pdfData: pdfBytes,
        ),
      ),
    );
  }

  Widget _buildNetSummaryBanner({
    required double rev,
    required double exp,
    required double net,
    required String currency,
    required ColorScheme cs,
    required LedgerPerspective perspective,
    required VoidCallback onExportExcel,
    required VoidCallback onExportPdf,
  }) {
    String primaryLabel;
    String secondaryLabel;
    String netLabel;

    switch (perspective) {
      case LedgerPerspective.combined:
        primaryLabel = 'CLIENT REVENUE';
        secondaryLabel = 'VENDOR EXPENSES';
        netLabel = 'NET BALANCE POSITION (RECEIVABLES - PAYABLES)';
        break;
      case LedgerPerspective.client:
        primaryLabel = 'CLIENT REVENUE';
        secondaryLabel = 'OTHER CREDITS';
        netLabel = 'TOTAL BILLED REVENUE';
        break;
      case LedgerPerspective.vendor:
        primaryLabel = 'DIRECT SUPPLIES';
        secondaryLabel = 'VENDOR EXPENSES';
        netLabel = 'TOTAL VENDOR PAYABLES';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryColumn(
                primaryLabel,
                rev,
                currency,
                const Color(0xFF4ade80),
              ),
              Container(
                width: 1,
                height: 40,
                color: cs.outline.withValues(alpha: 0.2),
              ),
              _summaryColumn(secondaryLabel, exp, currency, Colors.redAccent),
            ],
          ),
          const Divider(height: 28),
          Text(
            netLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatWithLabel(
              perspective == LedgerPerspective.combined
                  ? net
                  : (perspective == LedgerPerspective.client ? rev : exp),
              currency,
            ),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: perspective == LedgerPerspective.vendor
                  ? Colors.redAccent
                  : (net >= 0 ? const Color(0xFF4ade80) : Colors.redAccent),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportExcel,
                  icon: const Icon(
                    Icons.table_chart_outlined,
                    size: 18,
                    color: Colors.green,
                  ),
                  label: const Text(
                    'Export Excel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onExportPdf,
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Export PDF',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(
    String label,
    double val,
    String currency,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        Text(
          CurrencyFormatter.format(val, showDecimal: false),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderGroup(
    BuildContext context,
    OrderEntity order,
    List<OrderItemEntity> revItems,
    List<ExpenseEntity> revManual,
    List<OrderItemEntity> expItems,
    List<ExpenseEntity> expManual,
    String currency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final orderRevenue =
        (revItems.fold(0.0, (sum, i) => sum + i.amount) +
            revManual.fold(0.0, (sum, r) => sum + r.amount)) *
        (1 + order.vatRate);

    final orderExpense =
        expItems.fold(0.0, (sum, i) => sum + i.vendorAmount) +
        expManual.fold(0.0, (sum, e) => sum + e.amount);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        title: Text(
          order.eventName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'Order ID: ${order.id} | ${formatNepaliDate(order.eventDate, 'MMM dd, yyyy')}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (orderRevenue > 0)
              Text(
                '+ ${CurrencyFormatter.format(orderRevenue, showDecimal: false)}',
                style: const TextStyle(
                  color: Color(0xFF4ade80),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (orderExpense > 0)
              Text(
                '- ${CurrencyFormatter.format(orderExpense, showDecimal: false)}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (revItems.isNotEmpty || revManual.isNotEmpty) ...[
            _groupSubHeader('Revenue Details', const Color(0xFF4ade80)),
            ...revItems.map(
              (i) => _itemRow(
                i.itemName,
                '${i.quantity} ${i.unit} × ${i.days} days',
                i.amount,
                false,
              ),
            ),
            ...revManual.map(
              (r) => _itemRow(r.category, r.description, r.amount, false),
            ),
            const SizedBox(height: 8),
          ],
          if (expItems.isNotEmpty || expManual.isNotEmpty) ...[
            _groupSubHeader('Expense Details', Colors.redAccent),
            ...expItems.map(
              (i) => _itemRow(
                i.itemName,
                '${i.quantity} ${i.unit} × ${i.days} days',
                i.vendorAmount,
                true,
              ),
            ),
            ...expManual.map(
              (e) => _itemRow(e.category, e.description, e.amount, true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupSubHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(
    String title,
    String subtitle,
    double amount,
    bool isExpense,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(amount, showDecimal: false),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.redAccent : const Color(0xFF4ade80),
            ),
          ),
        ],
      ),
    );
  }
}
