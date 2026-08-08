import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashboardStripMode {
  thisWeek,
  upcoming,
  custom,
  all;

  String get label {
    switch (this) {
      case DashboardStripMode.thisWeek:
        return 'This Week';
      case DashboardStripMode.upcoming:
        return 'Upcoming';
      case DashboardStripMode.custom:
        return 'Custom Selection';
      case DashboardStripMode.all:
        return 'All Events';
    }
  }

  String get badgeText {
    switch (this) {
      case DashboardStripMode.thisWeek:
        return 'THIS WEEK';
      case DashboardStripMode.upcoming:
        return 'UPCOMING';
      case DashboardStripMode.custom:
        return 'FEATURED';
      case DashboardStripMode.all:
        return 'ALL EVENTS';
    }
  }
}

class DashboardStripState {
  final DashboardStripMode mode;
  final List<String> selectedEventIds;
  final bool isInitialized;

  const DashboardStripState({
    this.mode = DashboardStripMode.thisWeek,
    this.selectedEventIds = const [],
    this.isInitialized = false,
  });

  DashboardStripState copyWith({
    DashboardStripMode? mode,
    List<String>? selectedEventIds,
    bool? isInitialized,
  }) {
    return DashboardStripState(
      mode: mode ?? this.mode,
      selectedEventIds: selectedEventIds ?? this.selectedEventIds,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class DashboardStripNotifier extends Notifier<DashboardStripState> {
  static const _modePrefKey = 'dashboard_strip_mode';
  static const _selectedIdsPrefKey = 'dashboard_strip_selected_ids';

  @override
  DashboardStripState build() {
    _loadSettings();
    return const DashboardStripState();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_modePrefKey);
      final selectedIds = prefs.getStringList(_selectedIdsPrefKey) ?? [];

      final mode = (modeIndex != null && modeIndex < DashboardStripMode.values.length)
          ? DashboardStripMode.values[modeIndex]
          : DashboardStripMode.thisWeek;

      state = DashboardStripState(
        mode: mode,
        selectedEventIds: selectedIds,
        isInitialized: true,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> setMode(DashboardStripMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modePrefKey, mode.index);
  }

  Future<void> toggleEventSelection(String eventId) async {
    final currentIds = List<String>.from(state.selectedEventIds);
    if (currentIds.contains(eventId)) {
      currentIds.remove(eventId);
    } else {
      currentIds.add(eventId);
    }
    state = state.copyWith(selectedEventIds: currentIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefKey, currentIds);
  }

  Future<void> setSelectedEvents(List<String> eventIds) async {
    state = state.copyWith(selectedEventIds: eventIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefKey, eventIds);
  }

  Future<void> selectAllEvents(List<String> allIds) async {
    state = state.copyWith(selectedEventIds: allIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefKey, allIds);
  }

  Future<void> clearSelection() async {
    state = state.copyWith(selectedEventIds: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedIdsPrefKey, []);
  }
}

final dashboardStripNotifierProvider =
    NotifierProvider<DashboardStripNotifier, DashboardStripState>(() {
  return DashboardStripNotifier();
});
