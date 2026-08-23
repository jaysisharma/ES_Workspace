import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/widgets/dashboard/order_card.dart';
import 'package:order_app/presentation/widgets/dashboard/this_week_events_strip.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';

class FounderDashboard extends ConsumerStatefulWidget {
  const FounderDashboard({super.key});

  @override
  ConsumerState<FounderDashboard> createState() => _FounderDashboardState();
}

class _FounderDashboardState extends ConsumerState<FounderDashboard> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(orderNotifierProvider.notifier).loadOrders(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final orderIdNoSymbols = orderIdLower.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );

    return orderIdLower == query ||
        (cleanNoPrefix.isNotEmpty && orderIdLower == cleanNoPrefix) ||
        (cleanNoSymbols.isNotEmpty && orderIdNoSymbols == cleanNoSymbols) ||
        orderIdLower.contains(query) ||
        (cleanNoPrefix.isNotEmpty && orderIdLower.contains(cleanNoPrefix)) ||
        (cleanNoSymbols.isNotEmpty &&
            orderIdNoSymbols.contains(cleanNoSymbols));
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = const Color(0xFF8b5cf6); // Elegant Violet for Founder
    final bgColor = isDarkMode
        ? const Color(0xFF0b1319)
        : const Color(0xFFf8fafc);
    final cardBgColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);
    final textMuted = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final orderState = ref.watch(orderNotifierProvider);
    final eventState = ref.watch(eventsStreamProvider);
    final events = eventState.value ?? <EventEntity>[];
    final notificationState = ref.watch(notificationsStreamProvider);

    final unreadCount = notificationState.maybeWhen(
      data: (list) => list.where((n) => !n.isReadForUser(user?.id)).length,
      orElse: () => 0,
    );

    final ordersStream = ref.watch(ordersStreamProvider);
    final allOrders = ordersStream.maybeWhen(
      data: (list) => list,
      orElse: () => orderState.orders,
    );

    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults = isSearching
        ? allOrders
            .where((o) => _matchesOrderQuery(o, _searchQuery))
            .toList()
        : <OrderEntity>[];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Branding, Greeting, Short Search Bar & Notifications
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  // Optional Hamburger Drawer Button
                  Builder(
                    builder: (ctx) {
                      if (Scaffold.of(ctx).hasDrawer) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            icon: const Icon(Icons.menu_rounded, size: 22),
                            tooltip: 'Open Navigation Drawer',
                            style: IconButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? const Color(0xFF1e2d3d)
                                  : const Color(0xFFf1f5f9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Greeting & Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ES Workspace',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Manrope',
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FOUNDER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: primaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome, ${user?.email.split('@').first ?? 'Founder'} • ${formatNepaliDate(DateTime.now(), 'MMMM dd, yyyy')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Short Search Button / Bar in the Right Corner
                  _buildSearchWidget(
                    isDarkMode,
                    primaryColor,
                    cardBgColor,
                    borderColor,
                    textMuted,
                  ),

                  const SizedBox(width: 12),

                  // Notifications Button
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                        ),
                        tooltip: 'Notifications',
                        style: IconButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? const Color(0xFF1e2d3d)
                              : const Color(0xFFf1f5f9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const NotificationsScreen()),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content Area: Search Results or Actions Grid
            Expanded(
              child: isSearching
                  ? _buildSearchResultsView(
                      searchResults,
                      isDarkMode,
                      primaryColor,
                      cardBgColor,
                      borderColor,
                      textMuted,
                    )
                  : _buildMainDashboardActions(
                      context,
                      events,
                      isDarkMode,
                      primaryColor,
                      cardBgColor,
                      borderColor,
                      textMuted,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Search Input
  Widget _buildSearchWidget(
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    if (!_isSearchExpanded && _searchQuery.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.search_rounded, size: 22),
        tooltip: 'Search Orders',
        style: IconButton.styleFrom(
          backgroundColor: isDarkMode
              ? const Color(0xFF1e2d3d)
              : const Color(0xFFf1f5f9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          setState(() {
            _isSearchExpanded = true;
          });
          _searchFocusNode.requestFocus();
        },
      );
    }

    return Container(
      width: 260,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1e2d3d)
            : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search orders, venues…',
          hintStyle: TextStyle(fontSize: 12, color: textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _isSearchExpanded = false;
              });
              _searchFocusNode.unfocus();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // Search Results List
  Widget _buildSearchResultsView(
    List<OrderEntity> results,
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Results (${results.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Manrope',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _isSearchExpanded = false;
                  });
                  _searchFocusNode.unfocus();
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders found matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching by event name, client name, or order ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final order = results[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OrderCard(order: order, completion: 1.0),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Responsive Main Dashboard View
  Widget _buildMainDashboardActions(
    BuildContext context,
    List<EventEntity> events,
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;

        int crossAxisCount;
        double childAspectRatio;

        if (width >= 1200) {
          crossAxisCount = 5;
          childAspectRatio = 1.15;
        } else if (width >= 900) {
          crossAxisCount = 4;
          childAspectRatio = 1.1;
        } else if (width >= 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.05;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 0.95;
        }

        final hPadding = isMobile ? 16.0 : 24.0;
        final vPadding = isMobile ? 14.0 : 20.0;
        final gridSpacing = isMobile ? 12.0 : 18.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: vPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekly Events Strip
              if (events.isNotEmpty) ...[
                ThisWeekEventsStrip(events: events),
                SizedBox(height: isMobile ? 16 : 24),
              ],

              // Workspace Modules & Actions Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Workspace Modules & Actions',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 17,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Manrope',
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 12 : 16),

                    // Responsive Action Modules Grid (Exactly 5 Modules requested: Calendar, Event Reports, HR & Employees, Vendors, Clients)
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: childAspectRatio,
                      children: [
                        // 1. Calendar & Schedule
                        _buildModuleCard(
                          title: 'Calendar & Schedule',
                          subtitle: 'Event timelines & bookings',
                          icon: Icons.calendar_month_rounded,
                          accentColor: const Color(0xFF6366f1), // Indigo
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                          isMobile: isMobile,
                          onTap: () => Navigator.push(
                            context,
                            SlidePageRoute(page: const CalendarScreen()),
                          ),
                        ),

                        // 2. Event Reports
                        _buildModuleCard(
                          title: 'Event Reports',
                          subtitle: 'Event revenue & P&L reports',
                          icon: Icons.summarize_rounded,
                          accentColor: const Color(0xFFec4899), // Pink
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                          isMobile: isMobile,
                          onTap: () => Navigator.push(
                            context,
                            SlidePageRoute(
                              page: const EventFinancialReportScreen(),
                            ),
                          ),
                        ),

                        // 3. HR & Employees
                        _buildModuleCard(
                          title: 'HR & Employees',
                          subtitle: 'Manage team staff & leaves',
                          icon: Icons.badge_rounded,
                          accentColor: const Color(0xFF3b82f6), // Blue
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                          isMobile: isMobile,
                          onTap: () => Navigator.push(
                            context,
                            SlidePageRoute(
                              page: const HrManagementScreen(),
                            ),
                          ),
                        ),

                        // 4. Vendors
                        _buildModuleCard(
                          title: 'Vendors',
                          subtitle: 'Vendor directory & contacts',
                          icon: Icons.business_center_rounded,
                          accentColor: const Color(0xFFf59e0b), // Amber
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                          isMobile: isMobile,
                          onTap: () => Navigator.push(
                            context,
                            SlidePageRoute(page: const VendorScreen()),
                          ),
                        ),

                        // 5. Clients
                        _buildModuleCard(
                          title: 'Clients',
                          subtitle: 'Client directory & details',
                          icon: Icons.people_alt_rounded,
                          accentColor: const Color(0xFF8b5cf6), // Purple
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                          isMobile: isMobile,
                          onTap: () => Navigator.push(
                            context,
                            SlidePageRoute(page: const ClientScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Responsive Clickable Module Card — Identical sizing, circular icon badges, typography, and hover effects as Admin
  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color cardBgColor,
    required Color borderColor,
    required Color textMuted,
    required VoidCallback onTap,
    bool isProminent = false,
    bool isMobile = false,
  }) {
    final cardPaddingHorizontal = isMobile ? 10.0 : 16.0;
    final cardPaddingVertical = isMobile ? 12.0 : 18.0;
    final iconPadding = isMobile ? 10.0 : 14.0;
    final iconSize = isMobile ? 30.0 : 38.0;
    final spacingHeight = isMobile ? 8.0 : 12.0;
    final titleFontSize = isMobile ? 14.0 : 16.0;
    final subtitleFontSize = isMobile ? 11.0 : 12.0;

    return Material(
      color: isProminent ? accentColor.withValues(alpha: 0.05) : cardBgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: cardPaddingHorizontal,
            vertical: cardPaddingVertical,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isProminent
                  ? accentColor.withValues(alpha: 0.45)
                  : borderColor,
              width: isProminent ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: iconSize),
              ),
              SizedBox(height: spacingHeight),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
