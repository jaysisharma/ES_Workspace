import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/order_providers.dart';
import '../../providers/settings_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/order_entity.dart';
import 'order_details_screen.dart';

class EventFinancialReportScreen extends ConsumerStatefulWidget {
  const EventFinancialReportScreen({super.key});

  @override
  ConsumerState<EventFinancialReportScreen> createState() =>
      _EventFinancialReportScreenState();
}

class _EventFinancialReportScreenState
    extends ConsumerState<EventFinancialReportScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    final bgColor = colorScheme.surface;
    final cardColor = colorScheme.surface;
    final labelColor = colorScheme.onSurfaceVariant;
    final successColor = const Color(0xFF4ade80);
    final errorColor = colorScheme.error;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Event Financial Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _selectedDateRange = null),
            ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final filteredOrders = orders.where((o) {
            final query = _searchQuery.trim().toLowerCase();
            final nameMatch = o.eventName.toLowerCase().contains(query);
            final idMatch = o.id.toLowerCase().contains(query);
            final venueMatch = o.venue.toLowerCase().contains(query);
            final matchesQuery = nameMatch || idMatch || venueMatch;

            bool dateMatch = true;
            if (_selectedDateRange != null) {
              dateMatch =
                  o.eventDate.isAfter(
                    _selectedDateRange!.start.subtract(const Duration(days: 1)),
                  ) &&
                  o.eventDate.isBefore(
                    _selectedDateRange!.end.add(const Duration(days: 1)),
                  );
            }
            return matchesQuery && dateMatch && o.status != OrderStatus.draft;
          }).toList();

          double totalRevenue = 0;
          double totalExpenses = 0;
          for (var o in filteredOrders) {
            totalRevenue += o.totalAmount;
            totalExpenses += o.totalExpenses;
          }
          final totalProfit = totalRevenue - totalExpenses;

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by event name, Order ID, or venue...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: cardColor,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Summary Banner
              _buildSummaryBanner(
                context,
                totalRevenue,
                totalExpenses,
                totalProfit,
                currencyLabel,
              ),

              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Text(
                          'No reports found',
                          style: TextStyle(color: labelColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return _buildFinancialCard(
                            context,
                            order,
                            currencyLabel,
                            successColor,
                            errorColor,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context,
    double revenue,
    double expenses,
    double profit,
    String currency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: 'REV',
            value: revenue,
            currency: currency,
            color: colorScheme.primary,
          ),
          _SummaryItem(
            label: 'EXP',
            value: expenses,
            currency: currency,
            color: colorScheme.error,
          ),
          _SummaryItem(
            label: 'NET',
            value: profit,
            currency: currency,
            color: const Color(0xFF4ade80),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(
    BuildContext context,
    OrderEntity order,
    String currency,
    Color successColor,
    Color errorColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final profit = order.totalAmount - order.totalExpenses;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          SlidePageRoute(page: OrderDetailsScreen(order: order)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.eventName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order ID: ${order.id}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      formatNepaliDate(order.eventDate, 'MMM dd'),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _FinancialMiniStat(
                    label: 'Revenue',
                    value: order.totalAmount,
                    currency: currency,
                    color: colorScheme.onSurface,
                  ),
                  const Spacer(),
                  _FinancialMiniStat(
                    label: 'Expenses',
                    value: order.totalExpenses,
                    currency: currency,
                    color: errorColor,
                  ),
                  const Spacer(),
                  _FinancialMiniStat(
                    label: 'Profit',
                    value: profit,
                    currency: currency,
                    color: successColor,
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
          CurrencyFormatter.format(value, showDecimal: false),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FinancialMiniStat extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;
  final bool isBold;

  const _FinancialMiniStat({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 0.5,
            color: color.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          CurrencyFormatter.format(value, showDecimal: false),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
