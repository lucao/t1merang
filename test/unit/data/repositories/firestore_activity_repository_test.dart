import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/data/repositories/firestore_activity_repository.dart';
import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/repositories/params.dart';

// --- Mocks ---

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionRef;
  late FirestoreActivityRepository repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollectionRef = MockCollectionReference();

    when(() => mockFirestore.collection('activities'))
        .thenReturn(mockCollectionRef);

    repository = FirestoreActivityRepository(firestore: mockFirestore);
  });

  group('FirestoreActivityRepository', () {
    group('createActivity', () {
      test('creates activity with correct initial state and version', () async {
        final mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc()).thenReturn(mockDocRef);
        when(() => mockDocRef.id).thenReturn('test-activity-id');
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});

        final params = CreateActivityParams(
          title: 'Test Activity',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await repository.createActivity(params);

        expect(result.id, 'test-activity-id');
        expect(result.title, 'Test Activity');
        expect(result.currentStateId, 'backlog');
        expect(result.sectorId, 'sector-1');
        expect(result.createdBy, 'user-1');
        expect(result.responsibleUsers, ['user-1']);
        expect(result.isConflicted, false);
        expect(result.version, 1);
        expect(result.createdAt.isUtc, true);
        // Verify second precision (no milliseconds)
        expect(result.createdAt.millisecond, 0);
        expect(result.createdAt.microsecond, 0);

        final captured = verify(() => mockDocRef.set(captureAny())).captured;
        final data = captured.first as Map<String, dynamic>;
        expect(data['title'], 'Test Activity');
        expect(data['currentStateId'], 'backlog');
        expect(data['sectorId'], 'sector-1');
        expect(data['createdBy'], 'user-1');
        expect(data['responsibleUsers'], ['user-1']);
        expect(data['isConflicted'], false);
        expect(data['version'], 1);
      });
    });

    group('getActivity', () {
      test('returns activity from Firestore document', () async {
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockCollectionRef.doc('act-1')).thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn('act-1');
        when(() => mockSnapshot.data()).thenReturn({
          'title': 'My Activity',
          'currentStateId': 'development',
          'sectorId': 'sector-1',
          'createdAt': Timestamp.fromDate(DateTime.utc(2024, 1, 1, 12, 0, 0)),
          'createdBy': 'user-1',
          'lastModifiedAt':
              Timestamp.fromDate(DateTime.utc(2024, 1, 2, 10, 0, 0)),
          'lastModifiedBy': 'user-2',
          'stateEnteredAt':
              Timestamp.fromDate(DateTime.utc(2024, 1, 2, 10, 0, 0)),
          'responsibleUsers': ['user-1', 'user-2'],
          'isConflicted': false,
          'version': 3,
        });

        final result = await repository.getActivity('act-1');

        expect(result.id, 'act-1');
        expect(result.title, 'My Activity');
        expect(result.currentStateId, 'development');
        expect(result.version, 3);
        expect(result.responsibleUsers, ['user-1', 'user-2']);
      });

      test('throws when activity does not exist', () async {
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockCollectionRef.doc('missing')).thenReturn(mockDocRef);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(false);

        expect(
          () => repository.getActivity('missing'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('addTimelineEntry', () {
      test('writes timeline entry to subcollection', () async {
        final mockDocRef = MockDocumentReference();
        final mockTimelineCollection = MockCollectionReference();
        final mockEntryDocRef = MockDocumentReference();

        when(() => mockCollectionRef.doc('act-1')).thenReturn(mockDocRef);
        when(() => mockDocRef.collection('timeline'))
            .thenReturn(mockTimelineCollection);
        when(() => mockTimelineCollection.doc('entry-1'))
            .thenReturn(mockEntryDocRef);
        when(() => mockEntryDocRef.set(any())).thenAnswer((_) async {});

        final entry = TimelineEntry(
          id: 'entry-1',
          fromStateId: 'backlog',
          toStateId: 'development',
          transitionedAt: DateTime.utc(2024, 1, 15, 10, 30, 0),
          transitionedBy: 'user-1',
          durationMinutes: 120,
        );

        await repository.addTimelineEntry('act-1', entry);

        final captured =
            verify(() => mockEntryDocRef.set(captureAny())).captured;
        final data = captured.first as Map<String, dynamic>;
        expect(data['fromStateId'], 'backlog');
        expect(data['toStateId'], 'development');
        expect(data['transitionedBy'], 'user-1');
        expect(data['durationMinutes'], 120);
      });
    });

    group('withdrawResponsibility', () {
      test('calls update on the correct document reference', () async {
        final mockDocRef = MockDocumentReference();

        when(() => mockCollectionRef.doc('act-1')).thenReturn(mockDocRef);
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});

        await repository.withdrawResponsibility('act-1', 'user-2');

        verify(() => mockCollectionRef.doc('act-1')).called(1);
        verify(() => mockDocRef.update(any())).called(1);
      });
    });

    group('watchActivitiesBySector', () {
      test('queries by sectorId and returns stream of activities', () async {
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockDoc = MockQueryDocumentSnapshot();

        when(() => mockCollectionRef.where('sectorId', isEqualTo: 'sector-1'))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots())
            .thenAnswer((_) => Stream.value(mockQuerySnapshot));
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(() => mockDoc.id).thenReturn('act-1');
        when(() => mockDoc.data()).thenReturn({
          'title': 'Streamed Activity',
          'currentStateId': 'backlog',
          'sectorId': 'sector-1',
          'createdAt': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
          'createdBy': 'user-1',
          'lastModifiedAt': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
          'lastModifiedBy': 'user-1',
          'stateEnteredAt': Timestamp.fromDate(DateTime.utc(2024, 1, 1)),
          'responsibleUsers': ['user-1'],
          'isConflicted': false,
          'version': 1,
        });

        final activities =
            await repository.watchActivitiesBySector('sector-1').first;

        expect(activities.length, 1);
        expect(activities.first.id, 'act-1');
        expect(activities.first.title, 'Streamed Activity');
        expect(activities.first.currentStateId, 'backlog');
      });
    });
  });
}
