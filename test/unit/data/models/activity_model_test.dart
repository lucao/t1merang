import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/activity_model.dart';
import 'package:activity_tracker/domain/entities/activity.dart';

void main() {
  group('ActivityModel', () {
    final testDate = DateTime.utc(2024, 1, 15, 10, 30, 0);
    final testTimestamp = Timestamp.fromDate(testDate);

    final testFirestoreData = <String, dynamic>{
      'title': 'Test Activity',
      'currentStateId': 'state-1',
      'sectorId': 'sector-1',
      'createdAt': testTimestamp,
      'createdBy': 'user-1',
      'lastModifiedAt': testTimestamp,
      'lastModifiedBy': 'user-2',
      'stateEnteredAt': testTimestamp,
      'responsibleUsers': ['user-1', 'user-2'],
      'isConflicted': false,
      'version': 3,
    };

    test('fromFirestore creates model from Firestore data', () {
      final model = ActivityModel.fromFirestore(testFirestoreData, 'act-1');

      expect(model.id, 'act-1');
      expect(model.title, 'Test Activity');
      expect(model.currentStateId, 'state-1');
      expect(model.sectorId, 'sector-1');
      expect(model.createdAt, testDate);
      expect(model.createdBy, 'user-1');
      expect(model.lastModifiedAt, testDate);
      expect(model.lastModifiedBy, 'user-2');
      expect(model.stateEnteredAt, testDate);
      expect(model.responsibleUsers, ['user-1', 'user-2']);
      expect(model.isConflicted, false);
      expect(model.version, 3);
    });

    test('toFirestore serializes model to Firestore format', () {
      final model = ActivityModel(
        id: 'act-1',
        title: 'Test Activity',
        currentStateId: 'state-1',
        sectorId: 'sector-1',
        createdAt: testDate,
        createdBy: 'user-1',
        lastModifiedAt: testDate,
        lastModifiedBy: 'user-2',
        stateEnteredAt: testDate,
        responsibleUsers: ['user-1', 'user-2'],
        isConflicted: false,
        version: 3,
      );

      final data = model.toFirestore();

      expect(data['title'], 'Test Activity');
      expect(data['currentStateId'], 'state-1');
      expect(data['sectorId'], 'sector-1');
      expect(data['createdAt'], testTimestamp);
      expect(data['createdBy'], 'user-1');
      expect(data['lastModifiedAt'], testTimestamp);
      expect(data['lastModifiedBy'], 'user-2');
      expect(data['stateEnteredAt'], testTimestamp);
      expect(data['responsibleUsers'], ['user-1', 'user-2']);
      expect(data['isConflicted'], false);
      expect(data['version'], 3);
      // id should not be in Firestore data (it's the document ID)
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts to Activity entity', () {
      final model = ActivityModel.fromFirestore(testFirestoreData, 'act-1');
      final entity = model.toDomain();

      expect(entity, isA<Activity>());
      expect(entity.id, 'act-1');
      expect(entity.title, 'Test Activity');
      expect(entity.currentStateId, 'state-1');
      expect(entity.sectorId, 'sector-1');
      expect(entity.createdAt, testDate);
      expect(entity.createdBy, 'user-1');
      expect(entity.responsibleUsers, ['user-1', 'user-2']);
      expect(entity.isConflicted, false);
      expect(entity.version, 3);
    });

    test('fromDomain creates model from Activity entity', () {
      final entity = Activity(
        id: 'act-1',
        title: 'Test Activity',
        currentStateId: 'state-1',
        sectorId: 'sector-1',
        createdAt: testDate,
        createdBy: 'user-1',
        lastModifiedAt: testDate,
        lastModifiedBy: 'user-2',
        stateEnteredAt: testDate,
        responsibleUsers: ['user-1', 'user-2'],
        isConflicted: false,
        version: 3,
      );

      final model = ActivityModel.fromDomain(entity);

      expect(model.id, 'act-1');
      expect(model.title, 'Test Activity');
      expect(model.currentStateId, 'state-1');
      expect(model.version, 3);
    });

    test('round-trip: domain -> model -> firestore -> model -> domain', () {
      final original = Activity(
        id: 'act-1',
        title: 'Round Trip',
        currentStateId: 'state-2',
        sectorId: 'sector-3',
        createdAt: testDate,
        createdBy: 'user-5',
        lastModifiedAt: testDate,
        lastModifiedBy: 'user-5',
        stateEnteredAt: testDate,
        responsibleUsers: ['user-5'],
        isConflicted: true,
        version: 7,
      );

      final model = ActivityModel.fromDomain(original);
      final firestoreData = model.toFirestore();
      final restored = ActivityModel.fromFirestore(firestoreData, 'act-1');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
