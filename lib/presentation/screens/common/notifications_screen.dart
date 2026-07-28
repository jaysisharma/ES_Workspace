import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/notification_notifier.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../providers/order_providers.dart';
import '../../providers/event_providers.dart';
import 'order_details_screen.dart';
import 'event_task_detail_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0b111a)
        : const Color(0xFFf5f7f8);
    final surfaceColor = isDarkMode ? const Color(0xFF16202c) : Colors.white;
    final surfaceAccent = isDarkMode
        ? const Color(0xFF1e2a37)
        : const Color(0xFFe2e8f0);
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b).withValues(alpha: 0.5)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    // Status colors
    final emeraldColor = const Color(0xFF10b981);
    final amberColor = const Color(0xFFf59e0b);
    final purpleColor = const Color(0xFFa855f7);

    final notificationState = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF0b111a).withValues(alpha: 0.8)
                : const Color(0xFFf5f7f8).withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: labelColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? surfaceColor
                            : const Color(0xFFe2e8f0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(notificationNotifierProvider.notifier)
                        .markAllAsRead();
                  },
                  child: Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: notificationState.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: labelColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: labelColor, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupNotifications(notifications);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsStreamProvider);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final item = grouped[index];
                if (item is String) {
                  return _buildSectionHeader(item, labelColor);
                } else {
                  final n = item as NotificationEntity;
                  return Dismissible(
                    key: Key(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      color: Colors.redAccent,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      ref
                          .read(notificationNotifierProvider.notifier)
                          .deleteNotification(n.id);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Notification deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              ref
                                  .read(notificationNotifierProvider.notifier)
                                  .addNotification(n);
                            },
                          ),
                        ),
                      );
                    },
                    child: _buildNotificationCard(
                      notification: n,
                      isDarkMode: isDarkMode,
                      primaryColor: primaryColor,
                      surfaceAccent: surfaceAccent,
                      borderColor: borderColor,
                      textColor: textColor,
                      labelColor: labelColor,
                      emeraldColor: emeraldColor,
                      amberColor: amberColor,
                      purpleColor: purpleColor,
                      onTap: () async {
                        ref
                            .read(notificationNotifierProvider.notifier)
                            .markAsRead(n.id);

                        if (n.relatedId != null) {
                          // Fetch the order and navigate
                          try {
                            final orders = ref.read(orderNotifierProvider).orders;
                            final order = orders
                                .where((o) => o.id == n.relatedId)
                                .firstOrNull;

                            if (order != null && context.mounted) {
                              // Try to find if there is an event for this order
                              final events =
                                  ref.read(eventsStreamProvider).value ?? [];
                              final event = events
                                  .where((e) => e.orderId == order.id)
                                  .firstOrNull;

                              if (event != null) {
                                Navigator.push(
                                  context,
                                  SlidePageRoute(page: EventTaskDetailScreen(event: event)),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  SlidePageRoute(page: OrderDetailsScreen(order: order)),
                                );
                              }
                            }
                          } catch (e) {
                            // Order might not be loaded yet or deleted
                          }
                        }
                      },
                    ),
                  );
                }
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  List<dynamic> _groupNotifications(List<NotificationEntity> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<NotificationEntity>>{
      'TODAY': [],
      'YESTERDAY': [],
      'EARLIER': [],
    };

    for (final n in notifications) {
      final date = DateTime(
        n.timestamp.year,
        n.timestamp.month,
        n.timestamp.day,
      );
      if (date == today) {
        groups['TODAY']!.add(n);
      } else if (date == yesterday) {
        groups['YESTERDAY']!.add(n);
      } else {
        groups['EARLIER']!.add(n);
      }
    }

    final result = <dynamic>[];
    if (groups['TODAY']!.isNotEmpty) {
      result.add('TODAY');
      result.addAll(groups['TODAY']!);
    }
    if (groups['YESTERDAY']!.isNotEmpty) {
      result.add('YESTERDAY');
      result.addAll(groups['YESTERDAY']!);
    }
    if (groups['EARLIER']!.isNotEmpty) {
      result.add('EARLIER');
      result.addAll(groups['EARLIER']!);
    }
    return result;
  }

  Widget _buildSectionHeader(String title, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: labelColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required NotificationEntity notification,
    required bool isDarkMode,
    required Color primaryColor,
    required Color surfaceAccent,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color emeraldColor,
    required Color amberColor,
    required Color purpleColor,
    required VoidCallback onTap,
  }) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'order':
        icon = Icons.shopping_bag_outlined;
        color = primaryColor;
        break;
      case 'finance':
        icon = Icons.account_balance_wallet_outlined;
        color = emeraldColor;
        break;
      case 'warning':
        icon = Icons.error_outline_rounded;
        color = amberColor;
        break;
      case 'approval':
        icon = Icons.fact_check_outlined;
        color = emeraldColor;
        break;
      case 'system':
      default:
        icon = Icons.notifications_none_rounded;
        color = purpleColor;
    }

    final timeStr = _formatTime(notification.timestamp);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: !notification.isRead
              ? primaryColor.withValues(alpha: isDarkMode ? 0.1 : 0.05)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 12, color: labelColor),
                          ),
                          if (!notification.isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? const Color(0xFF94a3b8)
                          : const Color(0xFF475569),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatNepaliDate(timestamp, 'MMM dd');
  }
}
