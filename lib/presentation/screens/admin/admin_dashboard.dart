import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/order_providers.dart';
import '../../providers/event_providers.dart';
import '../../providers/dashboard_filter_notifier.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/event_entity.dart';
import '../../widgets/dashboard/admin_summary_card.dart';
import '../../widgets/dashboard/order_card.dart';
import '../common/notifications_screen.dart';
import '../common/calendar_screen.dart';
import 'synology_company_pdf_screen.dart';
import '../../providers/notification_notifier.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/user_entity.dart';
import '../../widgets/common/shimmer_loading.dart';
import '../../../core/utils/currency_formatter.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';

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
    super.dispose();
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

    return SafeArea(
      child: Column(
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
                                    ];

                                    return Row(
                                      children: filterOptions.map((option) {
                                        final isSelected =
                                            filterState.selectedFilter == option;

                                        String label;
                                        if (option == 'ALL') {
                                          label = 'ALL';
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
                                            backgroundColor: colorScheme
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

                              if (orders.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    child: Text(
                                      'No orders yet',
                                      style: TextStyle(color: labelColor),
                                    ),
                                  ),
                                )
                              else ...[
                                Consumer(
                                  builder: (context, ref, _) {
                                    final filterState = ref.watch(
                                      dashboardFilterNotifierProvider,
                                    );
                                    final filteredOrders = orders.where((o) {
                                      final matchesFilter =
                                          filterState.selectedFilter == 'ALL' ||
                                          o.status.name == filterState.selectedFilter;
                                      final matchesSearch =
                                          _searchQuery.isEmpty ||
                                          o.eventName.toLowerCase().contains(
                                            _searchQuery.toLowerCase(),
                                          ) ||
                                          o.id.toLowerCase().contains(
                                            _searchQuery.toLowerCase(),
                                          ) ||
                                          o.venue.toLowerCase().contains(
                                            _searchQuery.toLowerCase(),
                                          );
                                      return matchesFilter && matchesSearch;
                                    }).toList();

                                    if (filteredOrders.isEmpty) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 40,
                                          ),
                                          child: Text(
                                            'No orders match selected filter',
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
                                        if (orderModelState.isLoading && orders.isNotEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 20),
                                            child: Center(child: CircularProgressIndicator()),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],

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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: order2 != null
                      ? OrderCard(
                          order: order2,
                          completion: comp2,
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
          ),
        ),
      );
    }
    return list;
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
