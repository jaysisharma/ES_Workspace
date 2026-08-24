import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/widgets/dashboard/order_card.dart';
import 'package:order_app/presentation/widgets/dashboard/this_week_events_strip.dart';
import 'package:order_app/presentation/screens/common/orders/create_order_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/admin/admin_attendance_dashboard.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/orders/purchase_order_list_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/admin/archived_orders_screen.dart';
import 'package:order_app/presentation/screens/admin/bulk_delete_orders_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';
import 'package:order_app/presentation/screens/admin/manual_tasks_screen.dart';

class NewDashboard extends ConsumerStatefulWidget {
  const NewDashboard({super.key});

  @override
  ConsumerState<NewDashboard> createState() => _NewDashboardState();
}

class _NewDashboardState extends ConsumerState<NewDashboard> {
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
    final primaryColor = const Color(0xFF0075db);
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
              .where(
                (o) => !o.isArchived && _matchesOrderQuery(o, _searchQuery),
              )
              .toList()
        : <OrderEntity>[];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Responsive Header
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isMobile = headerConstraints.maxWidth < 650;
                final isMobileSearching =
                    isMobile && (_isSearchExpanded || _searchQuery.isNotEmpty);

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isMobileSearching
                        ? Row(
                            key: const ValueKey('mobile_search_header'),
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _isSearchExpanded = false;
                                  });
                                  _searchFocusNode.unfocus();
                                },
                              ),
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF192532)
                                        : const Color(0xFFf1f5f9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: primaryColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    autofocus: true,
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search order name, ID...',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        size: 18,
                                        color: textMuted,
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(
                                                  () => _searchQuery = '',
                                                );
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('standard_header'),
                            children: [
                              // Greeting & Title Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'ES Workspace',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: isMobile ? 17 : 20,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Manrope',
                                              letterSpacing: -0.5,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'ADMIN',
                                            style: TextStyle(
                                              fontSize: 9,
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
                                      'Welcome, ${user?.email.split('@').first ?? 'Admin'} • ${formatNepaliDate(DateTime.now(), 'MMM dd')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Search Widget (Icon on mobile, Expandable bar on Desktop/Tablet)
                              if (isMobile)
                                IconButton(
                                  icon: const Icon(
                                    Icons.search_rounded,
                                    size: 22,
                                  ),
                                  tooltip: 'Search',
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF1e2d3d)
                                        : const Color(0xFFf1f5f9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() => _isSearchExpanded = true);
                                  },
                                )
                              else
                                _buildDesktopSearchWidget(
                                  isDarkMode,
                                  primaryColor,
                                  cardBgColor,
                                  borderColor,
                                  textMuted,
                                ),

                              const SizedBox(width: 8),

                              // Notifications Button
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      unreadCount > 0
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
                                      size: 22,
                                      color: unreadCount > 0
                                          ? primaryColor
                                          : colorScheme.onSurface.withValues(
                                              alpha: 0.85,
                                            ),
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
                                        SlidePageRoute(
                                          page: const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -1,
                                      right: -1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFef4444),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: cardBgColor,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFef4444,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Center(
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                              letterSpacing: -0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // Desktop Refresh Button
                              if (!isMobile) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 22,
                                  ),
                                  tooltip: 'Refresh Dashboard',
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF1e2d3d)
                                        : const Color(0xFFf1f5f9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    ref.invalidate(eventsStreamProvider);
                                    ref.invalidate(ordersStreamProvider);
                                    ref.invalidate(notificationsStreamProvider);
                                    ref.invalidate(
                                      dashboardStripNotifierProvider,
                                    );
                                    await ref
                                        .read(orderNotifierProvider.notifier)
                                        .loadOrders();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Dashboard refreshed'),
                                          duration: Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                  ),
                );
              },
            ),

            // Body Area: Search Results OR Weekly Strip + Action Modules Grid
            Expanded(
              child: isSearching
                  ? _buildSearchResultsView(
                      searchResults,
                      primaryColor,
                      textMuted,
                      cardBgColor,
                      borderColor,
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

  // Desktop / Tablet Inline Search Bar
  Widget _buildDesktopSearchWidget(
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSearchExpanded || _searchQuery.isNotEmpty ? 280 : 200,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF192532) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _searchFocusNode.hasFocus ? primaryColor : borderColor,
          width: _searchFocusNode.hasFocus ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onTap: () => setState(() => _isSearchExpanded = true),
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search order name, ID...',
          hintStyle: TextStyle(fontSize: 12, color: textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  // Search Results View
  Widget _buildSearchResultsView(
    List<OrderEntity> results,
    Color primaryColor,
    Color textMuted,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Search Results for "$_searchQuery" (${results.length} found)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Manrope',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
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
          childAspectRatio = 0.98; // Well-proportioned for mobile screens
        }

        final hPadding = isMobile ? 16.0 : 24.0;
        final vPadding = isMobile ? 14.0 : 20.0;
        final gridSpacing = isMobile ? 12.0 : 18.0;

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            ref.invalidate(eventsStreamProvider);
            ref.invalidate(ordersStreamProvider);
            ref.invalidate(notificationsStreamProvider);
            ref.invalidate(dashboardStripNotifierProvider);
            await ref.read(orderNotifierProvider.notifier).loadOrders();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.symmetric(vertical: vPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly Events Strip (Full Width - 0 Horizontal Padding)
                ThisWeekEventsStrip(events: events),
                SizedBox(height: isMobile ? 16 : 24),

                // Workspace Modules & Actions Section (With Horizontal Padding)
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

                      // Responsive Action Modules Grid
                      GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: gridSpacing,
                        mainAxisSpacing: gridSpacing,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: childAspectRatio,
                        children: [
                          // Create New Order
                          _buildModuleCard(
                            title: 'Create Order',
                            subtitle: 'Register new event order',
                            icon: Icons.add_shopping_cart_rounded,
                            accentColor: const Color(0xFF0075db),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isProminent: true,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const CreateOrderScreen()),
                            ),
                          ),

                          // HR & Employees
                          _buildModuleCard(
                            title: 'HR & Employees',
                            subtitle: 'Manage team staff & leaves',
                            icon: Icons.badge_rounded,
                            accentColor: const Color(0xFF3b82f6),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const HrManagementScreen()),
                            ),
                          ),

                          // Assign Tasks
                          _buildModuleCard(
                            title: 'Assign Tasks',
                            subtitle: 'Give staff manual instructions',
                            icon: Icons.assignment_ind_rounded,
                            accentColor: const Color(0xFFf97316),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                  page: const ManualTasksScreen()),
                            ),
                          ),

                          // Attendance & Logs
                          _buildModuleCard(
                            title: 'Attendance & Logs',
                            subtitle: 'Staff check-ins & logs',
                            icon: Icons.access_time_filled_rounded,
                            accentColor: const Color(0xFF0d9488),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const AdminAttendanceDashboard(),
                              ),
                            ),
                          ),

                          // Vendors
                          _buildModuleCard(
                            title: 'Vendors',
                            subtitle: 'Vendor directory & contacts',
                            icon: Icons.business_center_rounded,
                            accentColor: const Color(0xFFf59e0b),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const VendorScreen()),
                            ),
                          ),

                          // Clients
                          _buildModuleCard(
                            title: 'Clients',
                            subtitle: 'Client directory & details',
                            icon: Icons.people_alt_rounded,
                            accentColor: const Color(0xFF8b5cf6),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const ClientScreen()),
                            ),
                          ),

                          // Purchase Orders
                          _buildModuleCard(
                            title: 'Purchase Orders',
                            subtitle: 'PO records & supply tracking',
                            icon: Icons.receipt_long_rounded,
                            accentColor: const Color(0xFF0284c7),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const PurchaseOrderListScreen(),
                              ),
                            ),
                          ),

                          // Financial Ledger
                          _buildModuleCard(
                            title: 'Financial Ledger',
                            subtitle: 'Transactions & ledger book',
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: const Color(0xFF10b981),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const FinancialLedgerScreen(),
                              ),
                            ),
                          ),

                          // Event Reports
                          _buildModuleCard(
                            title: 'Event Reports',
                            subtitle: 'Event revenue & P&L reports',
                            icon: Icons.summarize_rounded,
                            accentColor: const Color(0xFFec4899),
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

                          // Calendar & Schedule
                          _buildModuleCard(
                            title: 'Calendar & Schedule',
                            subtitle: 'Event timelines & bookings',
                            icon: Icons.calendar_month_rounded,
                            accentColor: const Color(0xFF6366f1),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const CalendarScreen()),
                            ),
                          ),

                          // Company Profile
                          _buildModuleCard(
                            title: 'Company Profile',
                            subtitle: 'Synology files & company doc',
                            icon: Icons.picture_as_pdf_rounded,
                            accentColor: const Color(0xFFe11d48),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const SynologyCompanyPdfScreen(),
                              ),
                            ),
                          ),

                          // Archived Orders
                          _buildModuleCard(
                            title: 'Archived Orders',
                            subtitle: 'View & restore archived events',
                            icon: Icons.inventory_2_rounded,
                            accentColor: const Color(0xFF64748b),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const ArchivedOrdersScreen(),
                              ),
                            ),
                          ),

                          // Bulk Delete Orders
                          _buildModuleCard(
                            title: 'Bulk Delete',
                            subtitle: 'Purge orders till date or #',
                            icon: Icons.delete_sweep_rounded,
                            accentColor: const Color(0xFFef4444),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(
                                page: const BulkDeleteOrdersScreen(),
                              ),
                            ),
                          ),

                          // System Settings
                          _buildModuleCard(
                            title: 'System Settings',
                            subtitle: 'Preferences & configurations',
                            icon: Icons.settings_rounded,
                            accentColor: const Color(0xFF475569),
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                            isMobile: isMobile,
                            onTap: () => Navigator.push(
                              context,
                              SlidePageRoute(page: const SettingsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Responsive Clickable Module Card
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
