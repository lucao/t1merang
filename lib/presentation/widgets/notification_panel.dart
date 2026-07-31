import 'package:flutter/material.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// A badge icon button that displays the unread notification count.
///
/// Shows a bell icon with a red badge overlay indicating the number
/// of unread notifications. Use this in an AppBar action slot.
class NotificationBadge extends StatelessWidget {
  /// Stream of notifications to compute the unread count from.
  final Stream<List<AppNotification>> notificationsStream;

  /// Called when the badge icon button is tapped.
  final VoidCallback onTap;

  const NotificationBadge({
    super.key,
    required this.notificationsStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((n) => !n.read).length;

        return IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(fontSize: 10),
            ),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: onTap,
          tooltip: 'Notifications',
        );
      },
    );
  }
}

/// A panel that displays a list of in-app notifications.
///
/// Notifications are sorted by [createdAt] descending (most recent first).
/// Unread notifications are visually distinct (bold title, highlighted background).
/// Tapping a notification marks it as read and invokes [onNotificationTap]
/// with the associated activity ID for navigation.
class NotificationPanel extends StatelessWidget {
  /// Stream of notifications to display.
  final Stream<List<AppNotification>> notificationsStream;

  /// Repository used to mark notifications as read.
  final NotificationRepository notificationRepository;

  /// Called when a notification is tapped, with the associated activity ID.
  final void Function(String activityId) onNotificationTap;

  const NotificationPanel({
    super.key,
    required this.notificationsStream,
    required this.notificationRepository,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No notifications',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Sort by createdAt descending (most recent first).
        final sorted = List<AppNotification>.from(notifications)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final notification = sorted[index];
            return _NotificationTile(
              notification: notification,
              onTap: () => _handleTap(notification),
            );
          },
        );
      },
    );
  }

  void _handleTap(AppNotification notification) {
    if (!notification.read) {
      notificationRepository.markAsRead(notification.id);
    }
    onNotificationTap(notification.activityId);
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;
    final theme = Theme.of(context);

    return ListTile(
      tileColor: isUnread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
          : null,
      leading: Icon(
        isUnread
            ? Icons.circle_notifications
            : Icons.notifications_none,
        color: isUnread ? theme.colorScheme.primary : Colors.grey,
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isUnread
                  ? theme.textTheme.bodyMedium?.color
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(notification.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: onTap,
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
