import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:order_app/domain/entities/event_pass_entity.dart';
import 'package:order_app/presentation/providers/event_pass_provider.dart';
import 'package:order_app/presentation/widgets/common/sync_setup_dialog.dart';
import 'package:order_app/presentation/screens/common/passes/create_event_pass_screen.dart';
import 'package:order_app/presentation/screens/common/passes/event_pass_details_screen.dart';
import 'package:order_app/presentation/screens/common/passes/scan_pass_screen.dart';

class EventPassesScreen extends ConsumerStatefulWidget {
  const EventPassesScreen({super.key});

  @override
  ConsumerState<EventPassesScreen> createState() => _EventPassesScreenState();
}

class _EventPassesScreenState extends ConsumerState<EventPassesScreen> {
  bool _isSearchVisible = false;
  String _searchQuery = '';
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventPassNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event Passes',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final syncState = ref.watch(syncProvider);
              String label = 'Cloud';
              IconData icon = Icons.cloud_done_outlined;
              Color color = Colors.green;

              if (syncState.mode == PassSyncMode.localHost) {
                label = 'Host';
                icon = Icons.router_outlined;
                color = Colors.blue;
              } else if (syncState.mode == PassSyncMode.localClient) {
                label = 'LAN';
                icon = Icons.settings_input_antenna_outlined;
                color = Colors.orange;
              }

              return TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SyncSetupDialog(),
                  );
                },
                icon: Icon(icon, color: color, size: 18),
                label: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) _searchQuery = '';
              });
            },
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
          ),
          IconButton(
            onPressed: () {
              context.pushPage(const ScanPassScreen());
            },
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Pass',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearchVisible ? 61.0 : 1.0),
          child: Column(
            children: [
              if (_isSearchVisible) _buildSearchBar(colorScheme),
              Container(color: colorScheme.outline.withValues(alpha: 0.1), height: 1),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_event_pass_fab',
        onPressed: () {
          context.pushPage(const CreateEventPassScreen());
        },
        backgroundColor: colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Pass',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(state, colorScheme),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10, top: 5),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 0;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by name, event or phone...',
          hintStyle: GoogleFonts.manrope(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        style: GoogleFonts.manrope(),
      ),
    );
  }

  Widget _buildBody(EventPassState state, ColorScheme colorScheme) {
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading passes',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(eventPassNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final passes = state.passes;
    final filteredPasses = passes.where((pass) {
      final matchesSearch =
          pass.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pass.eventName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          pass.clientPhone.contains(_searchQuery) ||
          (pass.companyName != null && pass.companyName!.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesSearch;
    }).toList();

    if (filteredPasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No event passes found' : 'No passes match your search',
              style: GoogleFonts.manrope(color: colorScheme.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Pagination logic
    const int itemsPerPage = 10;
    final totalPasses = filteredPasses.length;
    final totalPages = (totalPasses / itemsPerPage).ceil();

    if (_currentPage >= totalPages) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage) > totalPasses
        ? totalPasses
        : (startIndex + itemsPerPage);

    final currentPagePasses = filteredPasses.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(eventPassNotifierProvider.notifier).refresh(),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: currentPagePasses.length,
              itemBuilder: (context, index) {
                return _buildPassCard(currentPagePasses[index], colorScheme);
              },
            ),
          ),
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1} to $endIndex of $totalPasses passes',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Page ${_currentPage + 1} of $totalPages',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(8),
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
  }

  Widget _buildPassCard(EventPassEntity pass, ColorScheme colorScheme) {
    final redeemedCount = pass.services.where((s) => s.isRedeemed).length;
    final totalCount = pass.services.length;
    final allRedeemed = redeemedCount == totalCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          context.pushPage(EventPassDetailsScreen(pass: pass));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pass.clientName,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: allRedeemed
                          ? Colors.grey[200]
                          : (redeemedCount > 0 ? Colors.amber[50] : Colors.green[50]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      allRedeemed
                          ? 'Fully Redeemed'
                          : (redeemedCount > 0 ? 'Partially' : 'Active'),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: allRedeemed
                            ? Colors.grey[700]
                            : (redeemedCount > 0 ? Colors.amber[800] : Colors.green[800]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    pass.eventName,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    pass.clientPhone,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(pass.createdAt),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: allRedeemed ? colorScheme.onSurfaceVariant : colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$redeemedCount / $totalCount Redeemed',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: allRedeemed ? colorScheme.onSurfaceVariant : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
