import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/event_notifier.dart';
import 'package:order_app/presentation/screens/admin/bulk_delete_orders_screen.dart';
import 'package:order_app/presentation/screens/common/orders/order_details_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class ArchivedOrdersScreen extends ConsumerStatefulWidget {
  const ArchivedOrdersScreen({super.key});

  @override
  ConsumerState<ArchivedOrdersScreen> createState() =>
      _ArchivedOrdersScreenState();
}

class _ArchivedOrdersScreenState extends ConsumerState<ArchivedOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL';
  String _selectedTypeFilter = 'ALL';
  String _selectedSortBy = 'DATE_DESC';

  final Set<String> _optimisticRestoredIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderNotifierProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(OrderEntity order, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return order.id.toLowerCase().contains(q) ||
        order.eventName.toLowerCase().contains(q) ||
        order.venue.toLowerCase().contains(q) ||
        order.client.toLowerCase().contains(q) ||
        order.contactPerson.toLowerCase().contains(q) ||
        order.contactNumber.toLowerCase().contains(q) ||
        order.category.toLowerCase().contains(q);
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return const Color(0xFF0075db);
      case OrderStatus.inProgress:
        return const Color(0xFFf59e0b);
      case OrderStatus.completed:
        return const Color(0xFF10b981);
      case OrderStatus.locked:
        return const Color(0xFF8b5cf6);
      case OrderStatus.draft:
        return const Color(0xFF94a3b8);
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.locked:
        return 'Locked';
      case OrderStatus.draft:
        return 'Draft';
    }
  }

  Future<void> _unarchiveOrder(OrderEntity order) async {
    // 1. Instant Optimistic UI Update (0ms latency)
    setState(() {
      _optimisticRestoredIds.add(order.id);
    });

    // 2. Instant Feedback Toast with UNDO Option
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Restored "${order.eventName}" (#${order.id}) to active orders',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFFDE047),
          onPressed: () async {
            setState(() {
              _optimisticRestoredIds.remove(order.id);
            });
            await ref
                .read(orderNotifierProvider.notifier)
                .toggleArchiveOrder(order.id, true);
            ref.invalidate(ordersStreamProvider);
          },
        ),
        backgroundColor: const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    // 3. Parallel Background Synchronization
    try {
      final events = ref.read(eventsStreamProvider).value ?? [];
      final linkedEvent = events
          .where((e) => e.orderId == order.id)
          .firstOrNull;

      await Future.wait([
        ref
            .read(orderNotifierProvider.notifier)
            .toggleArchiveOrder(order.id, false),
        if (linkedEvent != null)
          ref
              .read(eventNotifierProvider.notifier)
              .toggleArchiveEvent(linkedEvent.id, false),
      ]);

      ref.invalidate(ordersStreamProvider);
      ref.invalidate(eventsStreamProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticRestoredIds.remove(order.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore order: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<OrderEntity> _sortOrders(List<OrderEntity> list) {
    final sorted = List<OrderEntity>.from(list);
    switch (_selectedSortBy) {
      case 'DATE_DESC':
        sorted.sort((a, b) => b.eventDate.compareTo(a.eventDate));
        break;
      case 'DATE_ASC':
        sorted.sort((a, b) => a.eventDate.compareTo(b.eventDate));
        break;
      case 'AMOUNT_DESC':
        sorted.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'ID_DESC':
        sorted.sort((a, b) => b.id.compareTo(a.id));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0075db);
    final bgColor = isDark ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final cardBgColor = isDark ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDark
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    // Watch stream and notifier
    final ordersStream = ref.watch(ordersStreamProvider);
    final orderNotifierState = ref.watch(orderNotifierProvider);

    final allOrders = ordersStream.maybeWhen(
      data: (list) => list,
      orElse: () => orderNotifierState.orders,
    );

    // Filter only archived orders (excluding optimistically restored orders)
    final archivedOrders = allOrders
        .where((o) => o.isArchived && !_optimisticRestoredIds.contains(o.id))
        .toList();

    // Filter by search query
    final searchFiltered = archivedOrders
        .where((o) => _matchesQuery(o, _searchQuery))
        .toList();

    // Filter by status dropdown
    final statusFiltered = searchFiltered.where((o) {
      if (_selectedStatusFilter == 'ALL') return true;
      return o.status.name.toUpperCase() == _selectedStatusFilter;
    }).toList();

    // Filter by type dropdown
    final typeFiltered = statusFiltered.where((o) {
      if (_selectedTypeFilter == 'ALL') return true;
      if (_selectedTypeFilter == 'RENTAL') {
        return o.orderType.toLowerCase() == 'rental';
      }
      return o.orderType.toLowerCase() != 'rental';
    }).toList();

    // Sorted result
    final finalOrders = _sortOrders(typeFiltered);

    final currencyFormatter = NumberFormat.currency(
      symbol: 'Rs. ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.archive_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Archived Orders',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textPrimary,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${archivedOrders.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            tooltip: 'Bulk Purge Orders',
            onPressed: () => Navigator.push(
              context,
              SlidePageRoute(page: const BulkDeleteOrdersScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Column(
            children: [
              // Minimal Filter & Search Toolbar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: isDesktop
                    ? _buildDesktopToolbar(
                        isDark,
                        cardBgColor,
                        borderColor,
                        textPrimary,
                        textMuted,
                        primaryColor,
                        archivedOrders,
                      )
                    : _buildMobileToolbar(
                        isDark,
                        cardBgColor,
                        borderColor,
                        textPrimary,
                        textMuted,
                        primaryColor,
                        archivedOrders,
                      ),
              ),

              // Orders Grid / List Area
              Expanded(
                child: finalOrders.isEmpty
                    ? _buildEmptyState(
                        isDark,
                        textPrimary,
                        textMuted,
                        archivedOrders.isEmpty,
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1380),
                          child: isDesktop
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            constraints.maxWidth >= 1300
                                            ? 3
                                            : 2,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        mainAxisExtent: 175,
                                      ),
                                  itemCount: finalOrders.length,
                                  itemBuilder: (context, index) =>
                                      _buildOrderCard(
                                        finalOrders[index],
                                        isDark,
                                        cardBgColor,
                                        borderColor,
                                        textPrimary,
                                        textMuted,
                                        primaryColor,
                                        currencyFormatter,
                                      ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: finalOrders.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _buildOrderCard(
                                        finalOrders[index],
                                        isDark,
                                        cardBgColor,
                                        borderColor,
                                        textPrimary,
                                        textMuted,
                                        primaryColor,
                                        currencyFormatter,
                                      ),
                                ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopToolbar(
    bool isDark,
    Color cardBgColor,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
    List<OrderEntity> archivedOrders,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1380),
        child: Row(
          children: [
            // Search Input
            Expanded(
              flex: 4,
              child: _buildSearchInput(
                isDark,
                borderColor,
                textPrimary,
                textMuted,
                primaryColor,
              ),
            ),
            const SizedBox(width: 12),

            // Status Dropdown
            _buildStatusDropdown(
              isDark,
              borderColor,
              textPrimary,
              textMuted,
              primaryColor,
              archivedOrders,
            ),
            const SizedBox(width: 10),

            // Order Type Dropdown
            _buildTypeDropdown(
              isDark,
              borderColor,
              textPrimary,
              textMuted,
              primaryColor,
            ),
            const SizedBox(width: 10),

            // Sort Dropdown
            _buildSortDropdown(
              isDark,
              borderColor,
              textPrimary,
              textMuted,
              primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileToolbar(
    bool isDark,
    Color cardBgColor,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
    List<OrderEntity> archivedOrders,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchInput(
          isDark,
          borderColor,
          textPrimary,
          textMuted,
          primaryColor,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatusDropdown(
                isDark,
                borderColor,
                textPrimary,
                textMuted,
                primaryColor,
                archivedOrders,
              ),
              const SizedBox(width: 8),
              _buildTypeDropdown(
                isDark,
                borderColor,
                textPrimary,
                textMuted,
                primaryColor,
              ),
              const SizedBox(width: 8),
              _buildSortDropdown(
                isDark,
                borderColor,
                textPrimary,
                textMuted,
                primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchInput(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
  ) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192532) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _searchQuery.isNotEmpty ? primaryColor : borderColor,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(fontSize: 13, color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by event, client, order #...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: textMuted.withValues(alpha: 0.8),
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
    List<OrderEntity> orders,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192532) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedStatusFilter != 'ALL' ? primaryColor : borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatusFilter,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: textMuted),
          style: TextStyle(
            fontSize: 12.5,
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: isDark ? const Color(0xFF192532) : Colors.white,
          onChanged: (val) {
            if (val != null) setState(() => _selectedStatusFilter = val);
          },
          items: [
            DropdownMenuItem(
              value: 'ALL',
              child: Text('All Statuses (${orders.length})'),
            ),
            DropdownMenuItem(
              value: 'CONFIRMED',
              child: Text(
                'Confirmed (${orders.where((o) => o.status == OrderStatus.confirmed).length})',
              ),
            ),
            DropdownMenuItem(
              value: 'INPROGRESS',
              child: Text(
                'In Progress (${orders.where((o) => o.status == OrderStatus.inProgress).length})',
              ),
            ),
            DropdownMenuItem(
              value: 'COMPLETED',
              child: Text(
                'Completed (${orders.where((o) => o.status == OrderStatus.completed).length})',
              ),
            ),
            DropdownMenuItem(
              value: 'LOCKED',
              child: Text(
                'Locked (${orders.where((o) => o.status == OrderStatus.locked).length})',
              ),
            ),
            DropdownMenuItem(
              value: 'DRAFT',
              child: Text(
                'Draft (${orders.where((o) => o.status == OrderStatus.draft).length})',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192532) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedTypeFilter != 'ALL' ? primaryColor : borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTypeFilter,
          icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: textMuted),
          style: TextStyle(
            fontSize: 12.5,
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: isDark ? const Color(0xFF192532) : Colors.white,
          onChanged: (val) {
            if (val != null) setState(() => _selectedTypeFilter = val);
          },
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Types')),
            DropdownMenuItem(value: 'EVENT', child: Text('Events')),
            DropdownMenuItem(value: 'RENTAL', child: Text('Rentals')),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192532) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSortBy,
          icon: Icon(Icons.sort_rounded, size: 16, color: textMuted),
          style: TextStyle(
            fontSize: 12.5,
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: isDark ? const Color(0xFF192532) : Colors.white,
          onChanged: (val) {
            if (val != null) setState(() => _selectedSortBy = val);
          },
          items: const [
            DropdownMenuItem(value: 'DATE_DESC', child: Text('Newest Date')),
            DropdownMenuItem(value: 'DATE_ASC', child: Text('Oldest Date')),
            DropdownMenuItem(
              value: 'AMOUNT_DESC',
              child: Text('Highest Amount'),
            ),
            DropdownMenuItem(value: 'ID_DESC', child: Text('Order #')),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    OrderEntity order,
    bool isDark,
    Color cardBgColor,
    Color borderColor,
    Color textPrimary,
    Color textMuted,
    Color primaryColor,
    NumberFormat currencyFormatter,
  ) {
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final isRental = order.orderType.toLowerCase() == 'rental';

    String formattedDate = '';
    try {
      formattedDate = formatNepaliDate(order.eventDate, 'd MMM yyyy');
    } catch (_) {
      formattedDate = DateFormat('dd MMM yyyy').format(order.eventDate);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(page: OrderDetailsScreen(order: order)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar: Order ID, Type Badge, Status Pill, and Restore
              Row(
                children: [
                  Text(
                    '#${order.id}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (isRental) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8b5cf6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RENTAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8b5cf6),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Compact 1-Tap Restore Button
                  InkWell(
                    onTap: () => _unarchiveOrder(order),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.unarchive_rounded,
                            size: 13,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Restore',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Event Name
              Text(
                order.eventName.isNotEmpty ? order.eventName : 'Unnamed Event',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  fontFamily: 'Manrope',
                ),
              ),

              // Metadata Row: Date & Venue
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12.5,
                    color: textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                  if (order.venue.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.location_on_rounded,
                      size: 12.5,
                      color: textMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        order.venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: textMuted),
                      ),
                    ),
                  ],
                ],
              ),

              // Bottom Row: Client Name + Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.client.isNotEmpty
                          ? order.client
                          : (order.contactPerson.isNotEmpty
                                ? order.contactPerson
                                : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ),
                  Text(
                    currencyFormatter.format(order.totalAmount),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textPrimary,
    Color textMuted,
    bool isCompletelyEmpty,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF192532)
                    : const Color(0xFFf1f5f9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isCompletelyEmpty ? 'No Archived Orders' : 'No Matching Orders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? 'Orders archived from order details or dashboard will appear here.'
                  : 'Try clearing your search query or selecting a different filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
