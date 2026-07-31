import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/notification_model.dart';
import 'package:activity_tracker/domain/entities/app_notification.dart';

void main() {
  group('NotificationModel', () {
    final testDate = DateTime.utc(2024, 4, 1, 12, 0, 0);
    final testTimestamp = Timestamp.fromDate(testDate);

    test('fromFirestore creates model from Firestore data', () {
      final data = <String, dynamic>{
        'userId': 'user-1',
        'type': 'state_change',
        'activityId': 'act-1',
        'title': 'Activity moved',
        'body': 'Activity "Task" moved from Backlog to Development',
        'read': false,
        'createdAt': testTimestamp,
      };

      final model = NotificationModel.fromFirestore(data, 'notif-1');

      expect(model.id, 'notif-1');
      expect(model.userId, 'user-1');
      expect(model.type, 'state_change');
      expect(model.activityId, 'act-1');
      expect(model.title, 'Activity moved');
      expect(model.body, 'Activity "Task" moved from Backlog to Development');
      expect(model.read, false);
      expect(model.createdAt, testDate);
    });

    test('toFirestore serializes model correctly', () {
      final model = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        type: 'discussion',
        activityId: 'act-2',
        title: 'New post',
        body: 'A new post was added',
        read: true,
        createdAt: testDate,
      );

      final data = model.toFirestore();

      expect(data['userId'], 'user-1');
      expect(data['type'], 'discussion');
      expect(data['activityId'], 'act-2');
      expect(data['title'], 'New post');
      expect(data['body'], 'A new post was added');
      expect(data['read'], true);
      expect(data['createdAt'], testTimestamp);
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts to AppNotification entity', () {
      final model = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        type: 'conflict',
        activityId: 'act-1',
        title: 'Conflict detected',
        body: 'A conflict was detected on activity',
        read: false,
        createdAt: testDate,
      );

      final entity = model.toDomain();

      expect(entity, isA<AppNotification>());
      expect(entity.id, 'notif-1');
      expect(entity.type, 'conflict');
      expect(entity.read, false);
    });

    test('fromDomain creates model from AppNotification entity', () {
      final entity = AppNotification(
        id: 'notif-1',
        userId: 'user-1',
        type: 'ask_help',
        activityId: 'act-1',
        title: 'Help needed',
        body: 'Someone needs help',
        read: false,
        createdAt: testDate,
      );

      final model = NotificationModel.fromDomain(entity);

      expect(model.id, 'notif-1');
      expect(model.type, 'ask_help');
    });

    test('round-trip preserves all fields', () {
      final original = AppNotification(
        id: 'notif-1',
        userId: 'user-2',
        type: 'conflict_resolved',
        activityId: 'act-3',
        title: 'Conflict resolved',
        body: 'The conflict was resolved by consensus',
        read: true,
        createdAt: testDate,
      );

      final model = NotificationModel.fromDomain(original);
      final firestoreData = model.toFirestore();
      final restored = NotificationModel.fromFirestore(firestoreData, 'notif-1');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
