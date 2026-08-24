import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardStripState {
  final List<String> selectedEventIds;
  final bool isInitialized;

  const DashboardStripState({
    this.selectedEventIds = const [],
    this.isInitialized = false,
  });

  DashboardStripState copyWith({
    List<String>? selectedEventIds,
    bool? isInitialized,
  }) {
    return DashboardStripState(
      selectedEventIds: selectedEventIds ?? this.selectedEventIds,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class DashboardStripNotifier extends Notifier<DashboardStripState> {
  static const _selectedIdsPrefKey = 'dashboard_strip_selected_ids';

  @override
  DashboardStripState build() {
    _loadSettings();
    return const DashboardStripState();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedIds = prefs.getStringList(_selectedIdsPrefKey) ?? [];

      state = DashboardStripState(
        selectedEventIds: selectedIds,
        isInitialized: true,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
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
