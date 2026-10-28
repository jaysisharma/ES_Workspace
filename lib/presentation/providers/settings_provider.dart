import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final bool notificationsEnabled;
  final String? exportDestinationDirectory;
  final bool autoArrangeExportFolders;
  final String leaveResetCycle; // 'nepali_fiscal', 'nepali_year', 'calendar_year', 'manual'
  final DateTime? customLeaveCycleStartDate;
  // Company-wide flag (set by Super Admin) allowing other users to change their own password.
  final bool allowSelfPasswordChange;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.currency = 'NPR (Rs.)',
    this.notificationsEnabled = true,
    this.exportDestinationDirectory,
    this.autoArrangeExportFolders = true,
    this.leaveResetCycle = 'nepali_fiscal',
    this.customLeaveCycleStartDate,
    this.allowSelfPasswordChange = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    bool? notificationsEnabled,
    String? exportDestinationDirectory,
    bool? autoArrangeExportFolders,
    String? leaveResetCycle,
    DateTime? customLeaveCycleStartDate,
    bool? allowSelfPasswordChange,
    bool clearExportDir = false,
    bool clearCustomLeaveDate = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      exportDestinationDirectory: clearExportDir
          ? null
          : (exportDestinationDirectory ?? this.exportDestinationDirectory),
      autoArrangeExportFolders:
          autoArrangeExportFolders ?? this.autoArrangeExportFolders,
      leaveResetCycle: leaveResetCycle ?? this.leaveResetCycle,
      customLeaveCycleStartDate: clearCustomLeaveDate
          ? null
          : (customLeaveCycleStartDate ?? this.customLeaveCycleStartDate),
      allowSelfPasswordChange:
          allowSelfPasswordChange ?? this.allowSelfPasswordChange,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _themeKey = 'theme_mode';
  static const _currencyKey = 'currency';
  static const _notificationsKey = 'notifications_enabled';
  static const _exportDirKey = 'export_destination_directory';
  static const _autoArrangeKey = 'auto_arrange_export_folders';
  static const _leaveCycleKey = 'leave_reset_cycle';
  static const _leaveCycleDateKey = 'leave_cycle_start_date';

  @override
  SettingsState build() {
    _loadSettings();
    _listenToRemoteSettings();
    _listenToFeatureFlags();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    final currency = prefs.getString(_currencyKey) ?? 'NPR (Rs.)';
    final notifications = prefs.getBool(_notificationsKey) ?? true;
    final exportDir = prefs.getString(_exportDirKey);
    final autoArrange = prefs.getBool(_autoArrangeKey) ?? true;
    final leaveCycle = prefs.getString(_leaveCycleKey) ?? 'nepali_fiscal';
    final leaveCycleDateMillis = prefs.getInt(_leaveCycleDateKey);
    final leaveCycleDate = leaveCycleDateMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(leaveCycleDateMillis)
        : null;

    state = SettingsState(
      themeMode: ThemeMode.values[themeIndex],
      currency: currency,
      notificationsEnabled: notifications,
      exportDestinationDirectory: exportDir,
      autoArrangeExportFolders: autoArrange,
      leaveResetCycle: leaveCycle,
      customLeaveCycleStartDate: leaveCycleDate,
      allowSelfPasswordChange: state.allowSelfPasswordChange,
    );
  }

  void _listenToRemoteSettings() {
    FirebaseFirestore.instance
        .collection('settings')
        .doc('hr_settings')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final cycle = data['leaveResetCycle'] as String? ?? 'nepali_fiscal';
        final timestamp = data['customLeaveCycleStartDate'] as Timestamp?;
        final date = timestamp?.toDate();

        state = state.copyWith(
          leaveResetCycle: cycle,
          customLeaveCycleStartDate: date,
          clearCustomLeaveDate: date == null,
        );
      }
    });
  }

  void _listenToFeatureFlags() {
    FirebaseFirestore.instance
        .collection('settings')
        .doc('feature_flags')
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      state = state.copyWith(
        allowSelfPasswordChange:
            data?['allowSelfPasswordChange'] as bool? ?? false,
      );
    }, onError: (_) {});
  }

  Future<void> setAllowSelfPasswordChange(bool enabled) async {
    final previous = state.allowSelfPasswordChange;
    state = state.copyWith(allowSelfPasswordChange: enabled);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('feature_flags')
          .set({'allowSelfPasswordChange': enabled}, SetOptions(merge: true));
    } catch (e) {
      state = state.copyWith(allowSelfPasswordChange: previous);
      rethrow;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setCurrency(String currency) async {
    state = state.copyWith(currency: currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency);
  }

  Future<void> toggleNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  Future<void> setExportDestinationDirectory(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_exportDirKey);
      state = state.copyWith(clearExportDir: true);
    } else {
      await prefs.setString(_exportDirKey, path.trim());
      state = state.copyWith(exportDestinationDirectory: path.trim());
    }
  }

  Future<void> toggleAutoArrangeExportFolders(bool enabled) async {
    state = state.copyWith(autoArrangeExportFolders: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoArrangeKey, enabled);
  }

  Future<void> setLeaveResetCycle(String cycle) async {
    state = state.copyWith(leaveResetCycle: cycle);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_leaveCycleKey, cycle);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('hr_settings')
          .set({'leaveResetCycle': cycle}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> resetAllLeaveBalancesNow([DateTime? customStartDate]) async {
    final targetDate = customStartDate ?? DateTime.now();
    state = state.copyWith(customLeaveCycleStartDate: targetDate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leaveCycleDateKey, targetDate.millisecondsSinceEpoch);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
      .doc('hr_settings')
      .set({
        'customLeaveCycleStartDate': Timestamp.fromDate(targetDate),
        'lastResetAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> clearManualLeaveCycleDate() async {
    state = state.copyWith(clearCustomLeaveDate: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_leaveCycleDateKey);

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('hr_settings')
          .update({'customLeaveCycleStartDate': FieldValue.delete()});
    } catch (_) {}
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
