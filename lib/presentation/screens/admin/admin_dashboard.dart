import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/dashboard_filter_notifier.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/widgets/dashboard/admin_summary_card.dart';
import 'package:order_app/presentation/widgets/dashboard/order_card.dart';
import 'package:order_app/presentation/widgets/dashboard/this_week_events_strip.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => ref.read(orderNotifierProvider.notifier).loadOrders());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(orderNotifierProvider.notifier).loadMoreOrders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    Future.microtask(() => ref.read(orderSelectionModeProvider.notifier).setSelectionMode(false));
    super.dispose();
  }

  bool _isOrderIdMatch(OrderEntity o, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return false;

    final cleanNoSymbols = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final cleanNoPrefix = query
        .replaceAll('#', '')
        .replaceAll('order-', '')
        .replaceAll('ord-', '')
        .replaceAll('order', '')
        .replaceAll('id:', '')
        .trim();

    final orderIdLower = o.id.toLowerCase();
    final orderIdNoSymbols = orderIdLower.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    return orderIdLower == query ||
        (cleanNoPrefix.isNotEmpty && orderIdLower == cleanNoPrefix) ||
        (cleanNoSymbols.isNotEmpty && orderIdNoSymbols == cleanNoSymbols) ||
        orderIdLower.contains(query) ||
        (cleanNoPrefix.isNotEmpty && orderIdLower.contains(cleanNoPrefix)) ||
        (cleanNoSymbols.isNotEmpty && orderIdNoSymbols.contains(cleanNoSymbols));
  }

  bool _matchesOrderQuery(OrderEntity o, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    if (_isOrderIdMatch(o, rawQuery)) return true;

    return o.eventName.toLowerCase().contains(query) ||
        o.venue.toLowerCase().contains(query) ||
        o.client.toLowerCase().contains(query) ||
        o.contactPerson.toLowerCase().contains(query) ||
        o.contactNumber.toLowerCase().contains(query) ||
        o.category.toLowerCase().contains(query) ||
        o.notes.toLowerCase().contains(query) ||
        o.description.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final orderModelState = ref.watch(orderNotifierProvider);
    final orders = orderModelState.orders;
    final eventState = ref.watch(eventsStreamProvider);
    final notificationState = ref.watch(notificationsStreamProvider);

    final unreadCount = notificationState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authNotifierProvider);
    final isAdminOrFounder = authState.user?.role == UserRole.admin || authState.user?.role == UserRole.founder;

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
          // Custom Top App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (MediaQuery.of(context).size.width < 768)
                      Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: Icon(
                              Icons.menu_rounded,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          ref.watch(authNotifierProvider).user?.role == UserRole.admin 
                            ? 'ES Workspace Admin' 
                            : 'ES Workspace Team',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (defaultTargetPlatform != TargetPlatform.iOS &&
                        defaultTargetPlatform != TargetPlatform.android) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: colorScheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.picture_as_pdf_outlined, size: 16, color: colorScheme.primary),
                        label: Text(
                          'Company PDF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const NotificationsScreen()),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Global Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search event, order ID, or venue...',
                  hintStyle: TextStyle(color: labelColor, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: labelColor,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: orderModelState.isLoading && orders.isEmpty 
              ? _buildShimmerLoading(context)
              : (orderModelState.error != null && orders.isEmpty)
                ? Center(child: Text('Error: ${orderModelState.error}'))
                : Builder(
                    builder: (context) {
                      final events = eventState.maybeWhen(
                        data: (e) => e,
                        orElse: () => <EventEntity>[],
                      );

                      // Summary Logic — use full stream for accurate counts
                      final allOrdersAsync = ref.watch(ordersStreamProvider);
                      final allOrders = allOrdersAsync.maybeWhen(
                        data: (o) => o,
                        orElse: () => orders,
                      );
                      final totalOrders = allOrders.length;
                      final upcomingCount = allOrders
                          .where((o) => o.status == OrderStatus.confirmed)
                          .length;
                      final pendingRevenue = allOrders.fold(
                        0.0,
                        (sum, o) =>
                            sum +
                            (o.status == OrderStatus.confirmed ? o.totalAmount : 0),
                      );
                      final monthlyProfit = allOrders.fold(
                        0.0,
                        (sum, o) => sum + (o.totalAmount - o.totalExpenses),
                      );

                      final currencyLabel = settings.currency.split(' ').first;

                      return RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(orderNotifierProvider.notifier).loadOrders();
                          ref.invalidate(eventsStreamProvider);
                          ref.invalidate(notificationsStreamProvider);
                          ref.invalidate(allItemsStreamProvider);
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),

                              // This Week's Events Ticker Strip
                              ThisWeekEventsStrip(events: events),

                              // Summary Section
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                                child: Text(
                                  'Dashboard Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final isWide = MediaQuery.of(context).size.width >= 768;

                                  final card1 = AdminSummaryCard(
                                    label: 'TOTAL ORDERS',
                                    value: totalOrders.toString(),
                                    icon: Icons.shopping_cart_outlined,
                                    color: colorScheme.primary,
                                    isPrimary: true,
                                    width: isWide ? double.infinity : 176,
                                  );

                                  final card2 = AdminSummaryCard(
                                    label: 'UPCOMING',
                                    value: upcomingCount.toString(),
                                    icon: Icons.event_available_outlined,
                                    color: colorScheme.primary,
                                    width: isWide ? double.infinity : 176,
                                  );

                                  final card3 = AdminSummaryCard(
                                    label: 'PENDING REV',
                                    value: CurrencyFormatter.formatWithLabel(
                                      pendingRevenue,
                                      currencyLabel,
                                      showDecimal: false,
                                    ),
                                    icon: Icons.payments_outlined,
                                    color: colorScheme.secondary,
                                    width: isWide ? double.infinity : 176,
                                  );

                                  final card4 = AdminSummaryCard(
                                    label: 'MONTHLY PROFIT',
                                    value: CurrencyFormatter.formatWithLabel(
                                      monthlyProfit,
                                      currencyLabel,
                                      showDecimal: false,
                                    ),
                                    icon: Icons.trending_up,
                                    color: colorScheme.tertiary,
                                    iconColor: colorScheme.tertiary,
                                    width: isWide ? double.infinity : 176,
                                  );

                                  if (isWide) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          Expanded(child: card1),
                                          const SizedBox(width: 12),
                                          Expanded(child: card2),
                                          const SizedBox(width: 12),
                                          Expanded(child: card3),
                                          const SizedBox(width: 12),
                                          Expanded(child: card4),
                                        ],
                                      ),
                                    );
                                  }

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        card1,
                                        const SizedBox(width: 12),
                                        card2,
                                        const SizedBox(width: 12),
                                        card3,
                                        const SizedBox(width: 12),
                                        card4,
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Recent Orders
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Orders',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    if (isAdminOrFounder)
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                                              color: _isSelectionMode ? Colors.red : colorScheme.primary,
                                              size: 22,
                                            ),
                                            tooltip: _isSelectionMode ? 'Exit Select Mode' : 'Select Orders',
                                            onPressed: () {
                                              setState(() {
                                                _isSelectionMode = !_isSelectionMode;
                                                if (!_isSelectionMode) {
                                                  _selectedOrderIds.clear();
                                                }
                                                ref.read(orderSelectionModeProvider.notifier).setSelectionMode(_isSelectionMode);
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_sweep_rounded,
                                              color: Colors.red.shade400,
                                              size: 22,
                                            ),
                                            tooltip: 'Date-wise Bulk Delete',
                                            onPressed: () => _showBulkDateDeleteDialog(context, allOrders),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              SlidePageRoute(page: const CalendarScreen()),
                                            ),
                                            child: Text(
                                              'View All',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          SlidePageRoute(page: const CalendarScreen()),
                                        ),
                                        child: Text(
                                          'View All',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Filter Row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                physics: const BouncingScrollPhysics(),
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    final filterState = ref.watch(
                                      dashboardFilterNotifierProvider,
                                    );

                                    final filterOptions = [
                                      'ALL',
                                      OrderStatus.confirmed.name,
                                      OrderStatus.inProgress.name,
                                      OrderStatus.completed.name,
                                      OrderStatus.draft.name,
                                      'archived',
                                    ];

                                    return Row(
                                      children: filterOptions.map((option) {
                                        final isSelected =
                                            filterState.selectedFilter == option;

                                        String label;
                                        if (option == 'ALL') {
                                          label = 'ALL';
                                        } else if (option == 'archived') {
                                          label = 'ARCHIVED 📦';
                                        } else {
                                          label =
                                              option[0].toUpperCase() +
                                              option
                                                  .substring(1)
                                                  .replaceAllMapped(
                                                    RegExp(r'([A-Z])'),
                                                    (m) => ' ${m[1]}',
                                                  );
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(label),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              if (selected) {
                                                ref
                                                    .read(
                                                      dashboardFilterNotifierProvider
                                                          .notifier,
                                                    )
                                                    .setFilter(option);
                                              }
                                            },
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : labelColor,
                                            ),
                                            backgroundColor: isSelected
                                                ? colorScheme.primary
                                                : colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.2),
                                            selectedColor: colorScheme.primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme.outline.withValues(
                                                        alpha: 0.3,
                                                      ),
                                                width: 1.2,
                                              ),
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 4,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),

                              SizedBox(height: 20),

                              Consumer(
                                builder: (context, ref, _) {
                                  final filterState = ref.watch(
                                    dashboardFilterNotifierProvider,
                                  );
                                  final isSearching = _searchQuery.trim().isNotEmpty;
                                  final initialSource = isSearching ? allOrders : orders;
                                  final List<OrderEntity> sourceOrders;
                                  if (isSearching) {
                                    final idMatches = initialSource
                                        .where((o) => _isOrderIdMatch(o, _searchQuery))
                                        .toList();
                                    sourceOrders =
                                        idMatches.isNotEmpty ? idMatches : initialSource;
                                  } else {
                                    sourceOrders = initialSource;
                                  }

                                  if (sourceOrders.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 40),
                                        child: Text(
                                          isSearching
                                              ? 'No orders found matching "$_searchQuery"'
                                              : 'No orders yet',
                                          style: TextStyle(color: labelColor),
                                        ),
                                      ),
                                    );
                                  }

                                  final filteredOrders = sourceOrders.where((o) {
                                    final isArchivedFilter =
                                        filterState.selectedFilter.toLowerCase() == 'archived';

                                    final archiveMatch = isArchivedFilter
                                        ? o.isArchived
                                        : (isSearching ? true : !o.isArchived);

                                    final matchesFilter = isArchivedFilter
                                        ? true
                                        : (filterState.selectedFilter == 'ALL' ||
                                            isSearching ||
                                            o.status.name == filterState.selectedFilter);

                                    final matchesSearch = _matchesOrderQuery(o, _searchQuery);

                                    return archiveMatch && matchesFilter && matchesSearch;
                                  }).toList();

                                  if (filteredOrders.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 40,
                                        ),
                                        child: Text(
                                          isSearching
                                              ? 'No orders found matching "$_searchQuery"'
                                              : 'No orders match selected filter',
                                          style: TextStyle(color: labelColor),
                                        ),
                                      ),
                                    );
                                  }

                                  final allItemsAsync = ref.watch(
                                    allItemsStreamProvider,
                                  );
                                  final allItems = allItemsAsync.maybeWhen(
                                    data: (items) => items,
                                    orElse: () => <OrderItemEntity>[],
                                  );

                                  return Column(
                                    children: [
                                      ..._buildGroupedOrderList(
                                        filteredOrders,
                                        events,
                                        allItems,
                                      ),
                                      if (orderModelState.isLoading && orders.isNotEmpty && !isSearching)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20),
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      if (_isSelectionMode)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBulkSelectionBottomBar(context, orders),
        ),
    ],
  ),
);
  }

  List<Widget> _buildGroupedOrderList(
    List<OrderEntity> orders,
    List<EventEntity> events,
    List<OrderItemEntity> allItems,
  ) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final List<Widget> list = [];

    if (isWide) {
      for (int i = 0; i < orders.length; i += 2) {
        final order1 = orders[i];
        final orderItems1 = allItems.where((item) => item.orderId == order1.id).toList();
        final total1 = orderItems1.length;
        final completed1 = orderItems1.where((item) => item.isCompleted).length;
        final comp1 = total1 > 0 ? completed1 / total1 : 0.0;

        OrderEntity? order2;
        double comp2 = 0.0;
        if (i + 1 < orders.length) {
          order2 = orders[i + 1];
          final orderItems2 = allItems.where((item) => item.orderId == order2!.id).toList();
          final total2 = orderItems2.length;
          final completed2 = orderItems2.where((item) => item.isCompleted).length;
          comp2 = total2 > 0 ? completed2 / total2 : 0.0;
        }

        list.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OrderCard(
                    order: order1,
                    completion: comp1,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedOrderIds.contains(order1.id),
                    onSelectionChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedOrderIds.add(order1.id);
                        } else {
                          _selectedOrderIds.remove(order1.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: order2 != null
                      ? OrderCard(
                          order: order2,
                          completion: comp2,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedOrderIds.contains(order2.id),
                          onSelectionChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedOrderIds.add(order2!.id);
                              } else {
                                _selectedOrderIds.remove(order2!.id);
                              }
                            });
                          },
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        );
      }
      return list;
    }

    for (var order in orders) {
      final orderItems = allItems.where((i) => i.orderId == order.id).toList();

      final totalItems = orderItems.length;
      final completedItems = orderItems.where((i) => i.isCompleted).length;
      final completion = totalItems > 0 ? completedItems / totalItems : 0.0;

      list.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OrderCard(
            order: order,
            completion: completion,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedOrderIds.contains(order.id),
            onSelectionChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedOrderIds.add(order.id);
                } else {
                  _selectedOrderIds.remove(order.id);
                }
              });
            },
          ),
        ),
      );
    }
    return list;
  }

  Widget _buildBulkSelectionBottomBar(BuildContext context, List<OrderEntity> visibleOrders) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSelected = visibleOrders.isNotEmpty &&
        visibleOrders.every((o) => _selectedOrderIds.contains(o.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Checkbox(
              value: allSelected,
              activeColor: Colors.red,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedOrderIds.addAll(visibleOrders.map((o) => o.id));
                  } else {
                    _selectedOrderIds.clear();
                  }
                });
              },
            ),
            Text(
              '${_selectedOrderIds.length} Selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedOrderIds.clear();
                  ref.read(orderSelectionModeProvider.notifier).setSelectionMode(false);
                });
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _selectedOrderIds.isEmpty
                  ? null
                  : () => _confirmBulkDeleteSelected(context),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text('DELETE (${_selectedOrderIds.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBulkDeleteSelected(BuildContext context) async {
    if (_selectedOrderIds.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final count = _selectedOrderIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Order Deletion'),
        content: Text(
          'Are you sure you want to permanently delete $count selected orders?\n\nThis operation cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE ($count) ORDERS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final idsToDelete = _selectedOrderIds.toList();
      setState(() {
        _isSelectionMode = false;
        _selectedOrderIds.clear();
        ref.read(orderSelectionModeProvider.notifier).setSelectionMode(false);
      });

      try {
        await ref.read(orderNotifierProvider.notifier).deleteOrders(idsToDelete);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $count orders.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBulkDateDeleteDialog(BuildContext context, List<OrderEntity> allOrders) {
    String selectedPreset = 'till_yesterday';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    DateTime fromDate = DateTime(2020, 1, 1);
    DateTime toDate = DateTime(yesterday.year, yesterday.month, yesterday.day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;

            final matchingOrders = allOrders.where((o) {
              final targetDate = o.eventDate;
              final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
              final end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
              return targetDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                  targetDate.isBefore(end.add(const Duration(seconds: 1)));
            }).toList();

            final totalValue = matchingOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.date_range_rounded, color: Colors.red.shade400, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date-Wise Bulk Delete',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Batch delete event orders by date or preset',
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Quick Presets Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Till Yesterday'),
                              selected: selectedPreset == 'till_yesterday',
                              selectedColor: Colors.red.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedPreset == 'till_yesterday' ? Colors.red : colorScheme.onSurface,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedPreset = 'till_yesterday';
                                  final y = DateTime.now().subtract(const Duration(days: 1));
                                  fromDate = DateTime(2020, 1, 1);
                                  toDate = DateTime(y.year, y.month, y.day);
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Older Than 30 Days'),
                              selected: selectedPreset == 'older_30',
                              selectedColor: Colors.orange.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selectedPreset == 'older_30' ? Colors.orange.shade800 : colorScheme.onSurface,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedPreset = 'older_30';
                                  final t = DateTime.now().subtract(const Duration(days: 30));
                                  fromDate = DateTime(2020, 1, 1);
                                  toDate = DateTime(t.year, t.month, t.day);
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Custom Range'),
                              selected: selectedPreset == 'custom',
                              labelStyle: const TextStyle(fontSize: 12),
                              onSelected: (_) async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  initialDateRange: DateTimeRange(start: fromDate, end: toDate),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedPreset = 'custom';
                                    fromDate = picked.start;
                                    toDate = picked.end;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            initialDateRange: DateTimeRange(start: fromDate, end: toDate),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedPreset = 'custom';
                              fromDate = picked.start;
                              toDate = picked.end;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Date Range Selected',
                                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formatNepaliDate(fromDate, "yyyy-MM-dd")}  ➔  ${formatNepaliDate(toDate, "yyyy-MM-dd")}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.edit_calendar_rounded, color: colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Orders Found: ${matchingOrders.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            Text(
                              'Total Value: Rs. ${totalValue.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: matchingOrders.isEmpty
                          ? Center(
                              child: Text(
                                'No orders found in selected date range',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: matchingOrders.length,
                              separatorBuilder: (itemCtx, itemIdx) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = matchingOrders[index];
                                final dateToDisplay = order.eventDate;
                                return ListTile(
                                  dense: true,
                                  title: Text(order.eventName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${order.client} • ${formatNepaliDate(dateToDisplay, "yyyy-MM-dd")}',
                                  ),
                                  trailing: Text(
                                    'Rs. ${order.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: matchingOrders.isEmpty
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Confirm Date-Wise Bulk Delete'),
                                      content: Text(
                                        'Are you sure you want to permanently delete ALL ${matchingOrders.length} orders from ${formatNepaliDate(fromDate, "yyyy-MM-dd")} to ${formatNepaliDate(toDate, "yyyy-MM-dd")}?\n\nThis operation cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(dialogCtx, true),
                                          child: Text('DELETE ALL (${matchingOrders.length})'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final idsToDelete = matchingOrders.map((o) => o.id).toList();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    try {
                                      await ref.read(orderNotifierProvider.notifier).deleteOrders(idsToDelete);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully deleted ${idsToDelete.length} orders.'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to delete orders: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: Text(
                            'DELETE ALL (${matchingOrders.length}) ORDERS IN RANGE',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) => const OrderCardShimmer(),
      ),
    );
  }
}
