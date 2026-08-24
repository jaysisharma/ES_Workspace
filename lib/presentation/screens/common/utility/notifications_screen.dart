import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/screens/common/orders/order_details_screen.dart';
import 'package:order_app/presentation/screens/common/events/event_task_detail_screen.dart';
import 'package:order_app/presentation/screens/admin/hr_management_screen.dart';
import 'package:order_app/presentation/screens/staff/staff_attendance_screen.dart';
import 'package:order_app/presentation/screens/staff/tasks_screen.dart';
import 'package:order_app/presentation/screens/admin/manual_tasks_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<NotificationEntity> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(notifications.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count notification${count > 1 ? 's' : ''}?'),
        content: const Text('Are you sure you want to delete the selected notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final idsToDelete = _selectedIds.toList();
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      await ref.read(notificationNotifierProvider.notifier).deleteMultipleNotifications(idsToDelete);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count notification${count > 1 ? 's' : ''} deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleNotificationTap(NotificationEntity n) async {
    if (_isSelectionMode) {
      _toggleSelection(n.id);
      return;
    }

    ref.read(notificationNotifierProvider.notifier).markAsRead(n.id);

    final relatedId = n.relatedId?.trim();
    final titleLower = n.title.toLowerCase();
    final descLower = n.description.toLowerCase();
    final userRole = ref.read(authNotifierProvider).user?.role;

    // 1. Order or Event related notification
    if (relatedId != null && relatedId.isNotEmpty) {
      OrderEntity? order;

      // Check stream cache first
      final orders = ref.read(ordersStreamProvider).value ??
          ref.read(orderNotifierProvider).orders;
      order = orders.where((o) => o.id == relatedId).firstOrNull;

      // If not loaded in memory, fetch directly by ID
      if (order == null) {
        try {
          order = await ref.read(getOrderByIdUseCaseProvider)(relatedId);
        } catch (e) {
          debugPrint('Error fetching order by id $relatedId: $e');
        }
      }

      if (order != null && mounted) {
        if (userRole == UserRole.staff) {
          final events = ref.read(eventsStreamProvider).value ?? [];
          final event = events.where((e) => e.orderId == order!.id).firstOrNull;
          if (event != null) {
            Navigator.push(
              context,
              SlidePageRoute(page: EventTaskDetailScreen(event: event)),
            );
            return;
          }
        }
        Navigator.push(
          context,
          SlidePageRoute(page: OrderDetailsScreen(order: order)),
        );
        return;
      }
    }

    // 2. Leave / HR related notification
    if (titleLower.contains('leave') || descLower.contains('leave')) {
      if (!mounted) return;
      if (userRole == UserRole.admin || userRole == UserRole.founder) {
        Navigator.push(
          context,
          SlidePageRoute(page: const HrManagementScreen()),
        );
        return;
      } else if (userRole == UserRole.staff) {
        Navigator.push(
          context,
          SlidePageRoute(page: const StaffAttendanceScreen()),
        );
        return;
      }
    }

    // 3. Task related notification
    if (n.type == 'task' || titleLower.contains('task') || descLower.contains('task')) {
      if (!mounted) return;
      if (userRole == UserRole.staff) {
        Navigator.push(
          context,
          SlidePageRoute(page: const TasksScreen()),
        );
        return;
      } else if (userRole == UserRole.admin || userRole == UserRole.founder) {
        Navigator.push(
          context,
          SlidePageRoute(page: const ManualTasksScreen()),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b111a) : const Color(0xFFf5f7f8);
    final surfaceColor = isDarkMode ? const Color(0xFF16202c) : Colors.white;
    final surfaceAccent = isDarkMode ? const Color(0xFF1e2a37) : const Color(0xFFe2e8f0);
    final borderColor = isDarkMode
        ? const Color(0xFF1e293b).withValues(alpha: 0.5)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

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
                ? const Color(0xFF0b111a).withValues(alpha: 0.95)
                : const Color(0xFFf5f7f8).withValues(alpha: 0.95),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _isSelectionMode
                ? _buildSelectionAppBar(notificationState.value ?? [], primaryColor, labelColor, textColor)
                : _buildNormalAppBar(primaryColor, labelColor, textColor, surfaceColor, isDarkMode, notificationState.value ?? []),
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsStreamProvider);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final item = grouped[index];
                    if (item is String) {
                      return _buildSectionHeader(item, labelColor);
                    } else {
                      final n = item as NotificationEntity;
                      final isSelected = _selectedIds.contains(n.id);

                      Widget card = _buildNotificationCard(
                        notification: n,
                        isDarkMode: isDarkMode,
                        primaryColor: primaryColor,
                        surfaceAccent: surfaceAccent,
                        borderColor: isSelected ? primaryColor : borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                        emeraldColor: emeraldColor,
                        amberColor: amberColor,
                        purpleColor: purpleColor,
                        isSelected: isSelected,
                        isSelectionMode: _isSelectionMode,
                        onSelectionToggle: () => _toggleSelection(n.id),
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedIds.add(n.id);
                            });
                          }
                        },
                        onTap: () => _handleNotificationTap(n),
                      );

                      if (_isSelectionMode) {
                        return card;
                      }

                      return Dismissible(
                        key: Key(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          ref.read(notificationNotifierProvider.notifier).deleteNotification(n.id);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Notification deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  ref.read(notificationNotifierProvider.notifier).addNotification(n);
                                },
                              ),
                            ),
                          );
                        },
                        child: card,
                      );
                    }
                  },
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildNormalAppBar(
    Color primaryColor,
    Color labelColor,
    Color textColor,
    Color surfaceColor,
    bool isDarkMode,
    List<NotificationEntity> notifications,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        return Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: labelColor,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: isDarkMode ? surfaceColor : const Color(0xFFe2e8f0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: isCompact ? 17 : 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (notifications.isNotEmpty) ...[
              if (isCompact) ...[
                IconButton(
                  icon: const Icon(Icons.checklist_rounded, size: 20),
                  tooltip: 'Select',
                  style: IconButton.styleFrom(foregroundColor: primaryColor),
                  onPressed: () => setState(() => _isSelectionMode = true),
                ),
                IconButton(
                  icon: const Icon(Icons.done_all_rounded, size: 20),
                  tooltip: 'Mark all as read',
                  style: IconButton.styleFrom(foregroundColor: primaryColor),
                  onPressed: () {
                    ref.read(notificationNotifierProvider.notifier).markAllAsRead();
                  },
                ),
              ] else ...[
                TextButton.icon(
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Select'),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                  onPressed: () => setState(() => _isSelectionMode = true),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    ref.read(notificationNotifierProvider.notifier).markAllAsRead();
                  },
                  child: Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildSelectionAppBar(
    List<NotificationEntity> notifications,
    Color primaryColor,
    Color labelColor,
    Color textColor,
  ) {
    final allSelected = notifications.isNotEmpty && _selectedIds.length == notifications.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${_selectedIds.length} Selected',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCompact) ...[
              IconButton(
                icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 20),
                tooltip: allSelected ? 'Deselect All' : 'Select All',
                style: IconButton.styleFrom(foregroundColor: primaryColor),
                onPressed: () => _selectAll(notifications),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                tooltip: 'Delete Selected',
                onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
              ),
            ] else ...[
              TextButton.icon(
                icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
                label: Text(allSelected ? 'Deselect All' : 'Select All'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
                onPressed: () => _selectAll(notifications),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                tooltip: 'Delete Selected',
                onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        );
      },
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

    for (var n in notifications) {
      final nDate = DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      if (nDate.isAtSameMomentAs(today)) {
        groups['TODAY']!.add(n);
      } else if (nDate.isAtSameMomentAs(yesterday)) {
        groups['YESTERDAY']!.add(n);
      } else {
        groups['EARLIER']!.add(n);
      }
    }

    final result = [];
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: labelColor,
          letterSpacing: 1.2,
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
    bool isSelected = false,
    bool isSelectionMode = false,
    VoidCallback? onSelectionToggle,
    VoidCallback? onLongPress,
  }) {
    IconData icon;
    Color iconBg;
    Color iconColor;

    switch (notification.type) {
      case 'order':
        icon = Icons.shopping_bag_outlined;
        iconBg = emeraldColor.withValues(alpha: 0.1);
        iconColor = emeraldColor;
        break;
      case 'change_request':
        icon = Icons.edit_calendar_outlined;
        iconBg = amberColor.withValues(alpha: 0.1);
        iconColor = amberColor;
        break;
      case 'delivery':
        icon = Icons.local_shipping_outlined;
        iconBg = purpleColor.withValues(alpha: 0.1);
        iconColor = purpleColor;
        break;
      default:
        icon = Icons.notifications_none_outlined;
        iconBg = primaryColor.withValues(alpha: 0.1);
        iconColor = primaryColor;
    }

    final currentUserId = ref.watch(authNotifierProvider).user?.uid;
    final isItemRead = notification.isReadForUser(currentUserId);
    final dateStr = formatNepaliDate(notification.timestamp, 'hh:mm a');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isItemRead
            ? Colors.transparent
            : (isDarkMode ? const Color(0xFF16202c) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? primaryColor : (isItemRead ? Colors.transparent : borderColor),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: isSelected ? primaryColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) => onSelectionToggle?.call(),
                    activeColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isItemRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isItemRead
                              ? labelColor
                              : textColor.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isItemRead && !isSelectionMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
