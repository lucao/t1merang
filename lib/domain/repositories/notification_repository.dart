import '../entities/app_notification.dart';

/// Abstract repository for managing in-app notifications.
abstract class NotificationRepository {
  /// Watches notifications for a specific user in real-time.
  Stream<List<AppNotification>> watchNotifications(String userId);

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId);

  /// Sends an in-app notification to a specific user.
  Future<void> sendNotification({
    required String userId,
    required String type,
    required String activityId,
    required String title,
    required String body,
  });
}
