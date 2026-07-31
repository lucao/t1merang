import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/data/repositories/firestore_state_repository.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/sort_order.dart';
import 'package:activity_tracker/domain/repositories/params.dart';

// Mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockWriteBatch extends Mock implements WriteBatch {}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDocumentReference());
    registerFallbackValue(<String, dynamic>{});
  });

  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late FirestoreStateRepository repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();

    when(() => mockFirestore.collection('states')).thenReturn(mockCollection);

    repository = FirestoreStateRepository(firestore: mockFirestore);
  });

  group('FirestoreStateRepository', () {
    group('createState', () {
      test('creates state when under max limit', () async {
        final mockSnapshot = MockQuerySnapshot();
        final mockDocRef = MockDocumentReference();

        // Simulate 5 existing states (under limit)
        when(() => mockCollection.get())
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn(
          List.generate(5, (_) => MockQueryDocumentSnapshot()),
        );

        when(() => mockCollection.add(any()))
            .thenAnswer((_) async => mockDocRef);
        when(() => mockDocRef.id).thenReturn('new-state-id');

        final params = CreateStateParams(
          name: 'Testing',
          order: 3,
          sortOrder: SortOrder.newestFirst,
        );

        final result = await repository.createState(params);

        expect(result.id, 'new-state-id');
        expect(result.name, 'Testing');
        expect(result.order, 3);
        expect(result.sortOrder, SortOrder.newestFirst);
        expect(result.isDefault, false);
        expect(result.productionThresholdDays, isNull);

        verify(() => mockCollection.add(any())).called(1);
      });

      test('throws stateLimitReached when at max 10 states', () async {
        final mockSnapshot = MockQuerySnapshot();

        // Simulate 10 existing states (at limit)
        when(() => mockCollection.get())
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn(
          List.generate(10, (_) => MockQueryDocumentSnapshot()),
        );

        final params = CreateStateParams(
          name: 'Eleventh',
          order: 10,
          sortOrder: SortOrder.oldestFirst,
        );

        expect(
          () => repository.createState(params),
          throwsA(ActivityTrackerError.stateLimitReached),
        );
      });

      test('creates state with productionThresholdDays', () async {
        final mockSnapshot = MockQuerySnapshot();
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.get())
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn([]);

        when(() => mockCollection.add(any()))
            .thenAnswer((_) async => mockDocRef);
        when(() => mockDocRef.id).thenReturn('prod-state-id');

        final params = CreateStateParams(
          name: 'Production',
          order: 2,
          sortOrder: SortOrder.newestFirst,
          isDefault: true,
          productionThresholdDays: 30,
        );

        final result = await repository.createState(params);

        expect(result.id, 'prod-state-id');
        expect(result.name, 'Production');
        expect(result.isDefault, true);
        expect(result.productionThresholdDays, 30);
      });
    });

    group('deleteState', () {
      test('deletes the state document', () async {
        final mockDocRef = MockDocumentReference();

        when(() => mockCollection.doc('state-to-delete'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.delete()).thenAnswer((_) async {});

        await repository.deleteState('state-to-delete');

        verify(() => mockDocRef.delete()).called(1);
      });
    });

    group('watchStates', () {
      test('emits states ordered by order field', () async {
        final mockQuery = MockQuery();
        final mockSnapshot = MockQuerySnapshot();

        final doc1 = MockQueryDocumentSnapshot();
        final doc2 = MockQueryDocumentSnapshot();

        when(() => mockCollection.orderBy('order')).thenReturn(mockQuery);
        when(() => mockQuery.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));
        when(() => mockSnapshot.docs).thenReturn([doc1, doc2]);

        when(() => doc1.id).thenReturn('state-1');
        when(() => doc1.data()).thenReturn({
          'name': 'Backlog',
          'order': 0,
          'sortOrder': 'oldest_first',
          'isDefault': true,
          'productionThresholdDays': null,
        });

        when(() => doc2.id).thenReturn('state-2');
        when(() => doc2.data()).thenReturn({
          'name': 'Development',
          'order': 1,
          'sortOrder': 'newest_first',
          'isDefault': true,
          'productionThresholdDays': null,
        });

        final states = await repository.watchStates().first;

        expect(states.length, 2);
        expect(states[0].name, 'Backlog');
        expect(states[0].order, 0);
        expect(states[0].sortOrder, SortOrder.oldestFirst);
        expect(states[1].name, 'Development');
        expect(states[1].order, 1);
        expect(states[1].sortOrder, SortOrder.newestFirst);
      });

      test('seeds default states when collection is empty', () async {
        final mockQuery = MockQuery();
        final mockSnapshot = MockQuerySnapshot();
        final mockBatch = MockWriteBatch();

        when(() => mockCollection.orderBy('order')).thenReturn(mockQuery);
        when(() => mockQuery.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));
        when(() => mockSnapshot.docs).thenReturn([]);

        // Mocking the seeding batch write
        when(() => mockFirestore.batch()).thenReturn(mockBatch);
        when(() => mockCollection.doc()).thenReturn(MockDocumentReference());
        when(() => mockBatch.set(any(), any())).thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        final states = await repository.watchStates().first;

        // Should return 3 default states
        expect(states.length, 3);
        expect(states[0].name, 'Backlog');
        expect(states[0].order, 0);
        expect(states[0].sortOrder, SortOrder.oldestFirst);
        expect(states[1].name, 'Development');
        expect(states[1].order, 1);
        expect(states[1].sortOrder, SortOrder.newestFirst);
        expect(states[2].name, 'Production');
        expect(states[2].order, 2);
        expect(states[2].sortOrder, SortOrder.newestFirst);
        expect(states[2].productionThresholdDays, 30);

        // Verify batch was used for seeding
        verify(() => mockFirestore.batch()).called(1);
        verify(() => mockBatch.commit()).called(1);
      });
    });
  });
}
