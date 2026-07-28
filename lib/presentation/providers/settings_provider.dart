import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final bool notificationsEnabled;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.currency = 'NPR (Rs.)',
    this.notificationsEnabled = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _themeKey = 'theme_mode';
  static const _currencyKey = 'currency';
  static const _notificationsKey = 'notifications_enabled';

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    final currency = prefs.getString(_currencyKey) ?? 'NPR (Rs.)';
    final notifications = prefs.getBool(_notificationsKey) ?? true;

    state = SettingsState(
      themeMode: ThemeMode.values[themeIndex],
      currency: currency,
      notificationsEnabled: notifications,
    );
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
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
