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
import 'package:order_app/presentation/screens/common/finance/event_invoices_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_ledger_screen.dart';
import 'package:order_app/presentation/screens/common/finance/event_financial_report_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/vendor_screen.dart';
import 'package:order_app/presentation/screens/common/contacts/client_screen.dart';
import 'package:order_app/presentation/screens/common/events/calendar_screen.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/utility/settings_screen.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class FinanceDashboard extends ConsumerStatefulWidget {
  const FinanceDashboard({super.key});

  @override
  ConsumerState<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends ConsumerState<FinanceDashboard> {
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
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FINANCE',
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
                          'Welcome, ${user?.email.split('@').first ?? 'Finance'} • ${formatNepaliDate(DateTime.now(), 'MMMM dd, yyyy')}',
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
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content: Filtered Search Results OR Finance Dashboard Grid
            Expanded(
              child: isSearching
                  ? _buildSearchResults(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: isSearching
          ? BottomRightBackButton(
              label: 'Back to Dashboard',
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
    );
  }

  // Header Search Input Widget
  Widget _buildSearchWidget(
    bool isDarkMode,
    Color primaryColor,
    Color cardBgColor,
    Color borderColor,
    Color textMuted,
  ) {
    if (_isSearchExpanded) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 280,
        height: 40,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1b2631) : const Color(0xFFf1f5f9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search_rounded, size: 18, color: primaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search orders, clients, ID...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94a3b8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: textMuted,
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearchExpanded = false;
                });
                _searchFocusNode.unfocus();
              },
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.search_rounded, size: 20),
      tooltip: 'Search orders',
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
        _searchFocusNode.requestFocus();
      },
    );
  }

  // Search Results View
  Widget _buildSearchResults(
    List<OrderEntity> results,
    Color primaryColor,
    Color textMuted,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Results for "$_searchQuery" (${results.length} found)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Manrope',
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
                label: const Text('Back to Dashboard'),
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
                          size: 54,
                          color: textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders found matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 15,
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

  // Dashboard Body with Weekly Strip & Finance Action Modules
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
        final isWide = constraints.maxWidth >= 900;
        final gridCrossAxisCount = isWide
            ? 4
            : (constraints.maxWidth >= 600 ? 3 : 2);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekly Events Strip at the Top
              ThisWeekEventsStrip(events: events),
              const SizedBox(height: 20),

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
                  const Text(
                    'Finance Workspace Modules',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Manrope',
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Grid of Finance Action Buttons
              GridView.count(
                crossAxisCount: gridCrossAxisCount,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 1.15 : 1.05,
                children: [
                  // 1. Invoices & Billing
                  _buildModuleCard(
                    title: 'Invoices & Billing',
                    subtitle: 'Proforma invoices & billing',
                    icon: Icons.receipt_long_rounded,
                    accentColor: const Color(0xFF0075db), // Primary Blue
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    isProminent: true,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const EventInvoicesScreen()),
                    ),
                  ),

                  // 2. Financial Ledger
                  _buildModuleCard(
                    title: 'Financial Ledger',
                    subtitle: 'Transactions & ledger book',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFF10b981), // Emerald Green
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    isProminent: true,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const FinancialLedgerScreen()),
                    ),
                  ),

                  // 3. Event Reports
                  _buildModuleCard(
                    title: 'Event Reports',
                    subtitle: 'Event revenue & P&L reports',
                    icon: Icons.summarize_rounded,
                    accentColor: const Color(0xFFec4899), // Pink
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const EventFinancialReportScreen()),
                    ),
                  ),

                  // 4. HR & Employees
                  _buildModuleCard(
                    title: 'HR & Employees',
                    subtitle: 'Manage team staff & leaves',
                    icon: Icons.badge_rounded,
                    accentColor: const Color(0xFF3b82f6), // Blue
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const HrManagementScreen()),
                    ),
                  ),

                  // 5. Vendors
                  _buildModuleCard(
                    title: 'Vendors',
                    subtitle: 'Vendor directory & contacts',
                    icon: Icons.business_center_rounded,
                    accentColor: const Color(0xFFf59e0b), // Amber
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const VendorScreen()),
                    ),
                  ),

                  // 6. Clients
                  _buildModuleCard(
                    title: 'Clients',
                    subtitle: 'Client directory & details',
                    icon: Icons.people_alt_rounded,
                    accentColor: const Color(0xFF8b5cf6), // Purple
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const ClientScreen()),
                    ),
                  ),

                  // 7. Calendar & Schedule
                  _buildModuleCard(
                    title: 'Calendar & Schedule',
                    subtitle: 'Event timelines & bookings',
                    icon: Icons.calendar_month_rounded,
                    accentColor: const Color(0xFF6366f1), // Indigo
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const CalendarScreen()),
                    ),
                  ),

                  // 8. Company Profile
                  _buildModuleCard(
                    title: 'Company Profile',
                    subtitle: 'Synology files & company doc',
                    icon: Icons.picture_as_pdf_rounded,
                    accentColor: const Color(0xFFe11d48), // Rose
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                    ),
                  ),

                  // 9. System Settings
                  _buildModuleCard(
                    title: 'System Settings',
                    subtitle: 'Preferences & configurations',
                    icon: Icons.settings_rounded,
                    accentColor: const Color(0xFF64748b), // Slate
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textMuted: textMuted,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Easy Clickable Centered Module Card
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
  }) {
    return Material(
      color: isProminent ? accentColor.withValues(alpha: 0.05) : cardBgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 40),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Manrope',
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
