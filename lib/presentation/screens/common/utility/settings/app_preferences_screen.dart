import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/presentation/screens/admin/bulk_delete_orders_screen.dart';
import 'package:order_app/presentation/widgets/dashboard/dashboard_event_selection_dialog.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class AppPreferencesScreen extends ConsumerWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authNotifierProvider);
    final stripState = ref.watch(dashboardStripNotifierProvider);
    final isAdminOrFounder =
        authState.user?.role == UserRole.admin ||
        authState.user?.role == UserRole.founder;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0b1319)
        : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF1e2d3d)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final dividerColor = isDarkMode
        ? const Color(0xFF1e2d3d).withValues(alpha: 0.6)
        : const Color(0xFFe2e8f0);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textColor),
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'App & Display Preferences',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: 'Manrope',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildPreferenceRow(
                    title: 'Currency',
                    subtitle: 'Active transaction and invoice currency',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: _buildDropdown(
                      ['NPR (Rs.)', 'USD (\$)', 'EUR (€)'],
                      settings.currency,
                      isDarkMode,
                      primaryColor,
                      cardColor,
                      textColor,
                      labelColor,
                      (val) {
                        if (val != null) {
                          ref.read(settingsProvider.notifier).setCurrency(val);
                        }
                      },
                    ),
                  ),
                  Divider(height: 28, color: dividerColor),
                  _buildPreferenceRow(
                    title: 'Enable Notifications',
                    subtitle:
                        'Receive real-time order updates and system alerts',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: Switch.adaptive(
                      value: settings.notificationsEnabled,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        ref
                            .read(settingsProvider.notifier)
                            .toggleNotifications(val);
                      },
                    ),
                  ),
                  Divider(height: 28, color: dividerColor),
                  _buildPreferenceRow(
                    title: 'Dark Mode',
                    subtitle: 'Toggle dark interface appearance',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: Switch.adaptive(
                      value: isDarkMode,
                      activeTrackColor: primaryColor,
                      onChanged: (val) {
                        ref
                            .read(settingsProvider.notifier)
                            .setThemeMode(
                              val ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                    ),
                  ),
                  if (isAdminOrFounder) ...[
                    Divider(height: 28, color: dividerColor),
                    _buildPreferenceRow(
                      title: 'Dashboard Event Strip',
                      subtitle:
                          '${stripState.selectedEventIds.length} events selected',
                      textColor: textColor,
                      labelColor: labelColor,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final events =
                              ref.read(eventsStreamProvider).value ?? [];
                          DashboardEventSelectionDialog.show(context, events);
                        },
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                        label: Text(
                          'Configure',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: primaryColor.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 28, color: dividerColor),
                    _buildPreferenceRow(
                      title: 'Bulk Delete Orders',
                      subtitle: 'Purge historical orders till date or order #',
                      textColor: textColor,
                      labelColor: labelColor,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BulkDeleteOrdersScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Open Tool',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceRow({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color labelColor,
    required Widget child,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: labelColor, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        child,
      ],
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String value,
    bool isDarkMode,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color labelColor,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: cardColor,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: labelColor,
            size: 18,
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
