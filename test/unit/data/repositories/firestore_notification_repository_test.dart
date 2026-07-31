import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/data/repositories/firestore_notification_repository.dart';

// --- Mocks ---

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseMessaging mockMessaging;
  late MockCollectionReference mockNotificationsCollection;
  late MockCollectionReference mockUsersCollection;
  late FirestoreNotificationRepository repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockMessaging = MockFirebaseMessaging();
    mockNotificationsCollection = MockCollectionReference();
    mockUsersCollection = MockCollectionReference();

    when(() => mockFirestore.collection('notifications'))
        .thenReturn(mockNotificationsCollection);
    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);

    repository = FirestoreNotificationRepository(
      firestore: mockFirestore,
      messaging: mockMessaging,
    );
  });

  group('FirestoreNotificationRepository', () {
    group('markAsRead', () {
      test('updates the read field to true', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockNotificationsCollection.doc('notif-1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.update({'read': true}))
            .thenAnswer((_) async {});

        await repository.markAsRead('notif-1');

        verify(() => mockDocRef.update({'read': true})).called(1);
      });
    });

    group('sendNotification', () {
      test('creates a new notification document in Firestore', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockNotificationsCollection.doc()).thenReturn(mockDocRef);
        when(() => mockDocRef.id).thenReturn('generated-id');
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});

        await repository.sendNotification(
          userId: 'user-123',
          type: 'state_change',
          activityId: 'activity-456',
          title: 'Activity moved',
          body: 'Activity was moved to Development',
        );

        final captured =
            verify(() => mockDocRef.set(captureAny())).captured.single
                as Map<String, dynamic>;

        expect(captured['userId'], 'user-123');
        expect(captured['type'], 'state_change');
        expect(captured['activityId'], 'activity-456');
        expect(captured['title'], 'Activity moved');
        expect(captured['body'], 'Activity was moved to Development');
        expect(captured['read'], false);
        expect(captured['createdAt'], isA<Timestamp>());
      });
    });

    group('FCM token management', () {
      test('registerFcmToken stores token on user document', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockMessaging.getToken())
            .thenAnswer((_) async => 'fcm-token-abc');
        when(() => mockUsersCollection.doc('user-1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await repository.registerFcmToken('user-1');

        final captured =
            verify(() => mockDocRef.update(captureAny())).captured.single
                as Map<Object?, Object?>;

        expect(captured['fcmToken'], 'fcm-token-abc');
        expect(captured['fcmTokenUpdatedAt'], isA<FieldValue>());
      });

      test('registerFcmToken does nothing when token is null', () async {
        when(() => mockMessaging.getToken()).thenAnswer((_) async => null);

        await repository.registerFcmToken('user-1');

        verifyNever(() => mockUsersCollection.doc(any()));
      });

      test('updateFcmToken stores new token', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockUsersCollection.doc('user-1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await repository.updateFcmToken('user-1', 'new-token');

        final captured =
            verify(() => mockDocRef.update(captureAny())).captured.single
                as Map<Object?, Object?>;

        expect(captured['fcmToken'], 'new-token');
      });

      test('removeFcmToken deletes token fields from user document', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockUsersCollection.doc('user-1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await repository.removeFcmToken('user-1');

        verify(() => mockDocRef.update(any())).called(1);
      });

      test('onTokenRefresh returns the messaging token refresh stream',
          () async {
        when(() => mockMessaging.onTokenRefresh)
            .thenAnswer((_) => Stream.value('refreshed-token'));

        final stream = repository.onTokenRefresh();

        expect(await stream.first, 'refreshed-token');
      });
    });

    group('watchNotifications', () {
      test('queries notifications by userId ordered by createdAt descending',
          () {
        final mockQuery1 = MockQuery();
        final mockQuery2 = MockQuery();

        when(() => mockNotificationsCollection.where(
              'userId',
              isEqualTo: 'user-1',
            )).thenReturn(mockQuery1);
        when(() => mockQuery1.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery2);

        final mockSnapshot = MockQuerySnapshot();
        when(() => mockQuery2.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));

        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        when(() => mockDoc.id).thenReturn('notif-1');
        when(() => mockDoc.data()).thenReturn({
          'userId': 'user-1',
          'type': 'state_change',
          'activityId': 'act-1',
          'title': 'Test',
          'body': 'Body',
          'read': false,
          'createdAt': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
        });

        final stream = repository.watchNotifications('user-1');

        expect(
          stream,
          emits(isA<List>().having((l) => l.length, 'length', 1)),
        );
      });
    });
  });
}
