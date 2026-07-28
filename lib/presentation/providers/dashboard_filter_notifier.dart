import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardFilterState {
  final String selectedFilter; // "ALL" or OrderStatus.name
  final bool isInitialized;

  DashboardFilterState({
    this.selectedFilter = 'ALL',
    this.isInitialized = false,
  });

  DashboardFilterState copyWith({String? selectedFilter, bool? isInitialized}) {
    return DashboardFilterState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class DashboardFilterNotifier extends Notifier<DashboardFilterState> {
  static const _prefKey = 'dashboard_filter_single_status';

  @override
  DashboardFilterState build() {
    _loadFilters();
    return DashboardFilterState();
  }

  Future<void> _loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilter = prefs.getString(_prefKey);

      if (savedFilter != null) {
        state = state.copyWith(
          selectedFilter: savedFilter,
          isInitialized: true,
        );
      } else {
        state = state.copyWith(isInitialized: true);
      }
    } catch (e) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> setFilter(String filter) async {
    state = state.copyWith(selectedFilter: filter);

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, filter);
  }
}

final dashboardFilterNotifierProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilterState>(() {
      return DashboardFilterNotifier();
    });
