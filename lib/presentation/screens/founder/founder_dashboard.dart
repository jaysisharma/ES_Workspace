import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/founder_navigation_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:order_app/presentation/screens/common/orders/order_details_screen.dart';

class FounderDashboard extends ConsumerStatefulWidget {
  const FounderDashboard({super.key});

  @override
  ConsumerState<FounderDashboard> createState() => _FounderDashboardState();
}

class _FounderDashboardState extends ConsumerState<FounderDashboard> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(orderNotifierProvider.notifier).loadOrders();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(orderNotifierProvider.notifier).loadMoreOrders();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final orderState = ref.watch(orderNotifierProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    // Theme Colors
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0f1a23)
        : const Color(0xFFf5f7f8);
    final surfaceDark = isDarkMode ? const Color(0xFF1a2632) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF27313a)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    // Specific states colors
    final emeraldColor = const Color(0xFF10b981);
    final redColor = const Color(0xFFef4444);

    // Dynamic Calculations — use full stream for accurate totals
    final allOrdersForStats = ref
        .watch(ordersStreamProvider)
        .maybeWhen(data: (o) => o, orElse: () => orderState.orders);
    double totalRevenue = 0;
    double totalExpenses = 0;
    for (var order in allOrdersForStats) {
      if (order.status == OrderStatus.confirmed ||
          order.status == OrderStatus.completed) {
        totalRevenue += order.totalAmount;
        totalExpenses += order.totalExpenses;
      }
    }
    double netProfit = totalRevenue - totalExpenses;

    return Column(
      children: [
        // Custom Header
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 24,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF0f1a23)
                : const Color(0xFFf5f7f8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (MediaQuery.of(context).size.width < 768)
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: textColor),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Founder Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCpdfzoFLf8qOvLbd7LpBAwKlaiWZdvEeKL8S1dVXWYNAPp1M4kx3V7C8C71U5jo2Y30dqeYjdwfQFhkbCUCuppX_d3CWIz4UVsyFnDTxHsOTh6GP0EY_bcUvsvd4nJGgAki5JGUMNXYl1_lDsKRf1YMQPH7U7iuiFazYzeubyNtUeOHXBom06LTrp7LFBqvLAU4Ck-D66M4DmGlss8wGyvnPhILY4tkP-GqD5uaqzKRpuWHPltrCGYMC4g0ivZ7c-JRUT9e0HVRPI',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.person, color: labelColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: orderState.isLoading && orderState.orders.isEmpty
              ? _buildShimmerLoading(context)
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(orderNotifierProvider.notifier).loadOrders();
                    ref.invalidate(eventsStreamProvider);
                    ref.invalidate(allItemsStreamProvider);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: Financial Summary Cards
                        Builder(
                          builder: (context) {
                            final isWide =
                                MediaQuery.of(context).size.width >= 768;

                            final revCard = GestureDetector(
                              onTap: () {
                                ref
                                    .read(founderNavigationProvider.notifier)
                                    .setIndex(3); // FINANCE
                              },
                              child: _buildFinancialCard(
                                title: 'Total Revenue',
                                amount:
                                    '$currencyLabel ${CurrencyFormatter.formatCompact(totalRevenue)}',
                                icon: Icons.payments,
                                color: primaryColor,
                                surfaceDark: surfaceDark,
                                borderColor: borderColor,
                                textColor: textColor,
                                labelColor: labelColor,
                              ),
                            );

                            final expCard = _buildFinancialCard(
                              title: 'Total Expenses',
                              amount:
                                  '$currencyLabel ${CurrencyFormatter.formatCompact(totalExpenses)}',
                              icon: Icons.account_balance_wallet,
                              color: redColor,
                              surfaceDark: surfaceDark,
                              borderColor: borderColor,
                              textColor: textColor,
                              labelColor: labelColor,
                            );

                            final profitCard = _buildFinancialCard(
                              title: 'Net Profit',
                              amount:
                                  '$currencyLabel ${CurrencyFormatter.formatCompact(netProfit)}',
                              icon: Icons.trending_up,
                              color: emeraldColor,
                              surfaceDark: surfaceDark,
                              borderColor: borderColor,
                              textColor: textColor,
                              labelColor: labelColor,
                            );

                            if (isWide) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: revCard),
                                    const SizedBox(width: 16),
                                    Expanded(child: expCard),
                                    const SizedBox(width: 16),
                                    Expanded(child: profitCard),
                                  ],
                                ),
                              );
                            }

                            return SizedBox(
                              height: 140,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  revCard,
                                  const SizedBox(width: 16),
                                  expCard,
                                  const SizedBox(width: 16),
                                  profitCard,
                                ],
                              ),
                            );
                          },
                        ),

                        // Section 2: Revenue Chart
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RECENT EVENT REVENUE',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: labelColor,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '$currencyLabel ${totalRevenue.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Real-time Data',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: labelColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 160,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: orderState.orders.take(5).map((
                                      order,
                                    ) {
                                      double fraction = totalRevenue > 0
                                          ? order.totalAmount / totalRevenue
                                          : 0.1;
                                      return _buildChartBar(
                                        order.eventName
                                            .substring(
                                              0,
                                              order.eventName.length > 4
                                                  ? 4
                                                  : order.eventName.length,
                                            )
                                            .toUpperCase(),
                                        fraction.clamp(0.1, 1.0),
                                        primaryColor,
                                        isDarkMode,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Section 3: Recent Completed Events
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Recent Completed Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: eventsAsync.when(
                            data: (events) {
                              final completed = events
                                  .where((e) => e.status == 'Completed')
                                  .toList();
                              if (completed.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No completed events yet',
                                    style: TextStyle(color: labelColor),
                                  ),
                                );
                              }
                              return Column(
                                children: completed.take(3).map((event) {
                                  final associatedOrder = orderState.orders
                                      .cast<OrderEntity>()
                                      .firstWhere(
                                        (o) => o.id == event.orderId,
                                        orElse: () => OrderEntity(
                                          id: '',
                                          eventName: '',
                                          eventDate: DateTime.now(),
                                          setupDate: DateTime.now(),
                                          venue: '',
                                          status: OrderStatus.draft,
                                          contactPerson: '',
                                          contactNumber: '',
                                          notes: '',
                                          assignedStaffIds: const [],
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        ),
                                      );

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16.0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        if (associatedOrder.id.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            SlidePageRoute(
                                              page: OrderDetailsScreen(
                                                order: associatedOrder,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: _buildCompletedEventCard(
                                        title: event.title,
                                        date: event.date
                                            .toString()
                                            .split(' ')
                                            .first,
                                        revenue:
                                            '$currencyLabel ${CurrencyFormatter.formatCompact(associatedOrder.totalAmount)}',
                                        expenses:
                                            '$currencyLabel ${CurrencyFormatter.formatCompact(associatedOrder.totalExpenses)}',
                                        profit:
                                            '$currencyLabel ${CurrencyFormatter.formatCompact(associatedOrder.totalAmount - associatedOrder.totalExpenses)}',
                                        surfaceDark: surfaceDark,
                                        borderColor: borderColor,
                                        textColor: textColor,
                                        labelColor: labelColor,
                                        primaryColor: primaryColor,
                                        emeraldColor: emeraldColor,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => const SizedBox(),
                          ),
                        ),

                        // Section 4: Active Events Overview
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Active Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: eventsAsync.when(
                            data: (events) {
                              final active = events
                                  .where((e) => e.status != 'Completed')
                                  .toList();
                              if (active.isEmpty) {
                                return const Center(
                                  child: Text('No active events'),
                                );
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  children: active.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final event = entry.value;

                                    final allItemsAsync = ref.watch(
                                      allItemsStreamProvider,
                                    );
                                    final allItems = allItemsAsync.maybeWhen(
                                      data: (items) => items,
                                      orElse: () => <OrderItemEntity>[],
                                    );

                                    final orderItems = allItems
                                        .where(
                                          (i) => i.orderId == event.orderId,
                                        )
                                        .toList();
                                    final totalItems = orderItems.length;
                                    final completedItems = orderItems
                                        .where((i) => i.isCompleted)
                                        .length;
                                    final completion = totalItems > 0
                                        ? completedItems / totalItems
                                        : 0.0;

                                    return _buildActiveEventRow(
                                      title: event.title,
                                      status: event.status,
                                      progressLabel: 'Live Status',
                                      completion: completion,
                                      statusColor: event.status == 'Planning'
                                          ? primaryColor
                                          : const Color(0xFFf59e0b),
                                      isDarkMode: isDarkMode,
                                      bgColor: bgColor,
                                      textColor: textColor,
                                      labelColor: labelColor,
                                      borderColor: borderColor,
                                      primaryColor: primaryColor,
                                      isLast: index == active.length - 1,
                                      onTap: () {
                                        final associatedOrder = orderState
                                            .orders
                                            .cast<OrderEntity>()
                                            .firstWhere(
                                              (o) => o.id == event.orderId,
                                              orElse: () => OrderEntity(
                                                id: '',
                                                eventName: '',
                                                eventDate: DateTime.now(),
                                                setupDate: DateTime.now(),
                                                venue: '',
                                                status: OrderStatus.draft,
                                                contactPerson: '',
                                                contactNumber: '',
                                                notes: '',
                                                assignedStaffIds: const [],
                                                createdAt: DateTime.now(),
                                                updatedAt: DateTime.now(),
                                              ),
                                            );
                                        if (associatedOrder.id.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            SlidePageRoute(
                                              page: OrderDetailsScreen(
                                                order: associatedOrder,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (_, _) => const SizedBox(),
                          ),
                        ),
                        if (orderState.isLoading &&
                            orderState.orders.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required Color surfaceDark,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(
    String label,
    double fraction,
    Color color,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: fraction),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedEventCard({
    required String title,
    required String date,
    required String revenue,
    required String expenses,
    required String profit,
    required Color surfaceDark,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color primaryColor,
    required Color emeraldColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Text(date, style: TextStyle(fontSize: 12, color: labelColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Rev', revenue, textColor),
              _buildMiniStat('Exp', expenses, labelColor),
              _buildMiniStat('Profit', profit, emeraldColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveEventRow({
    required String title,
    required String status,
    required String progressLabel,
    required double completion,
    required Color statusColor,
    required bool isDarkMode,
    required Color bgColor,
    required Color textColor,
    required Color labelColor,
    required Color borderColor,
    required Color primaryColor,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: completion,
                    backgroundColor: isDarkMode
                        ? Colors.black26
                        : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(completion * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => const OrderCardShimmer(),
      ),
    );
  }
}
