import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_notification.dart';

/// Firestore DTO for the AppNotification entity.
/// Maps to/from `/notifications/{notificationId}` documents.
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String activityId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.activityId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      activityId: data['activityId'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      read: data['read'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
    );
  }

  factory NotificationModel.fromDomain(AppNotification entity) {
    return NotificationModel(
      id: entity.id,
      userId: entity.userId,
      type: entity.type,
      activityId: entity.activityId,
      title: entity.title,
      body: entity.body,
      read: entity.read,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'activityId': activityId,
      'title': title,
      'body': body,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppNotification toDomain() {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      activityId: activityId,
      title: title,
      body: body,
      read: read,
      createdAt: createdAt,
    );
  }
}
