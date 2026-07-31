import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/timeline_entry_model.dart';
import 'package:activity_tracker/domain/entities/timeline_entry.dart';

void main() {
  group('TimelineEntryModel', () {
    final testDate = DateTime.utc(2024, 5, 10, 16, 45, 0);
    final testTimestamp = Timestamp.fromDate(testDate);

    test('fromFirestore creates model from Firestore data', () {
      final data = <String, dynamic>{
        'fromStateId': 'state-1',
        'toStateId': 'state-2',
        'transitionedAt': testTimestamp,
        'transitionedBy': 'user-1',
        'durationMinutes': 120,
      };

      final model = TimelineEntryModel.fromFirestore(data, 'entry-1');

      expect(model.id, 'entry-1');
      expect(model.fromStateId, 'state-1');
      expect(model.toStateId, 'state-2');
      expect(model.transitionedAt, testDate);
      expect(model.transitionedBy, 'user-1');
      expect(model.durationMinutes, 120);
    });

    test('toFirestore serializes model correctly', () {
      final model = TimelineEntryModel(
        id: 'entry-1',
        fromStateId: 'state-a',
        toStateId: 'state-b',
        transitionedAt: testDate,
        transitionedBy: 'user-2',
        durationMinutes: 45,
      );

      final data = model.toFirestore();

      expect(data['fromStateId'], 'state-a');
      expect(data['toStateId'], 'state-b');
      expect(data['transitionedAt'], testTimestamp);
      expect(data['transitionedBy'], 'user-2');
      expect(data['durationMinutes'], 45);
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts to TimelineEntry entity', () {
      final model = TimelineEntryModel(
        id: 'entry-1',
        fromStateId: 'state-1',
        toStateId: 'state-2',
        transitionedAt: testDate,
        transitionedBy: 'user-1',
        durationMinutes: 90,
      );

      final entity = model.toDomain();

      expect(entity, isA<TimelineEntry>());
      expect(entity.id, 'entry-1');
      expect(entity.fromStateId, 'state-1');
      expect(entity.toStateId, 'state-2');
      expect(entity.durationMinutes, 90);
    });

    test('fromDomain creates model from TimelineEntry entity', () {
      final entity = TimelineEntry(
        id: 'entry-1',
        fromStateId: 'state-1',
        toStateId: 'state-2',
        transitionedAt: testDate,
        transitionedBy: 'user-1',
        durationMinutes: 60,
      );

      final model = TimelineEntryModel.fromDomain(entity);

      expect(model.id, 'entry-1');
      expect(model.fromStateId, 'state-1');
      expect(model.durationMinutes, 60);
    });

    test('round-trip preserves all fields', () {
      final original = TimelineEntry(
        id: 'entry-1',
        fromStateId: 'state-a',
        toStateId: 'state-b',
        transitionedAt: testDate,
        transitionedBy: 'user-5',
        durationMinutes: 333,
      );

      final model = TimelineEntryModel.fromDomain(original);
      final firestoreData = model.toFirestore();
      final restored = TimelineEntryModel.fromFirestore(firestoreData, 'entry-1');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
