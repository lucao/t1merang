import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/conflict_model.dart';
import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';

void main() {
  group('ConflictModel', () {
    final testDate = DateTime.utc(2024, 2, 20, 8, 0, 0);
    final deadlineDate = DateTime.utc(2024, 2, 21, 8, 0, 0);
    final testTimestamp = Timestamp.fromDate(testDate);
    final deadlineTimestamp = Timestamp.fromDate(deadlineDate);

    test('fromFirestore creates model with versions and votes', () {
      final data = <String, dynamic>{
        'activityId': 'act-1',
        'fieldPath': 'title',
        'status': 'pending',
        'createdAt': testTimestamp,
        'votingDeadline': deadlineTimestamp,
        'resolvedAt': null,
        'resolutionMethod': null,
        'versions': [
          {
            'versionId': 'v1',
            'value': 'Title A',
            'authorId': 'user-1',
            'modifiedAt': testTimestamp,
          },
          {
            'versionId': 'v2',
            'value': 'Title B',
            'authorId': 'user-2',
            'modifiedAt': deadlineTimestamp,
          },
        ],
        'votes': {'user-3': 'v1'},
      };

      final model = ConflictModel.fromFirestore(data, 'conflict-1');

      expect(model.id, 'conflict-1');
      expect(model.activityId, 'act-1');
      expect(model.fieldPath, 'title');
      expect(model.status, 'pending');
      expect(model.createdAt, testDate);
      expect(model.votingDeadline, deadlineDate);
      expect(model.resolvedAt, null);
      expect(model.resolutionMethod, null);
      expect(model.versions.length, 2);
      expect(model.versions[0].versionId, 'v1');
      expect(model.versions[0].value, 'Title A');
      expect(model.versions[1].authorId, 'user-2');
      expect(model.votes, {'user-3': 'v1'});
    });

    test('toFirestore serializes all fields', () {
      final model = ConflictModel(
        id: 'conflict-1',
        activityId: 'act-1',
        fieldPath: 'title',
        status: 'resolved',
        createdAt: testDate,
        votingDeadline: deadlineDate,
        resolvedAt: deadlineDate,
        resolutionMethod: 'consensus',
        versions: [
          ConflictVersionModel(
            versionId: 'v1',
            value: 'Title A',
            authorId: 'user-1',
            modifiedAt: testDate,
          ),
        ],
        votes: {'user-1': 'v1', 'user-2': 'v1'},
      );

      final data = model.toFirestore();

      expect(data['activityId'], 'act-1');
      expect(data['fieldPath'], 'title');
      expect(data['status'], 'resolved');
      expect(data['resolvedAt'], deadlineTimestamp);
      expect(data['resolutionMethod'], 'consensus');
      expect((data['versions'] as List).length, 1);
      expect(data['votes'], {'user-1': 'v1', 'user-2': 'v1'});
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts to Conflict entity', () {
      final model = ConflictModel(
        id: 'conflict-1',
        activityId: 'act-1',
        fieldPath: 'title',
        status: 'pending',
        createdAt: testDate,
        votingDeadline: deadlineDate,
        versions: [
          ConflictVersionModel(
            versionId: 'v1',
            value: 'Hello',
            authorId: 'user-1',
            modifiedAt: testDate,
          ),
        ],
        votes: {},
      );

      final entity = model.toDomain();

      expect(entity, isA<Conflict>());
      expect(entity.id, 'conflict-1');
      expect(entity.status, ConflictStatus.pending);
      expect(entity.versions.length, 1);
      expect(entity.versions[0], isA<ConflictVersion>());
      expect(entity.versions[0].versionId, 'v1');
    });

    test('fromDomain creates model from Conflict entity', () {
      final entity = Conflict(
        id: 'conflict-1',
        activityId: 'act-1',
        fieldPath: 'title',
        status: ConflictStatus.resolved,
        createdAt: testDate,
        votingDeadline: deadlineDate,
        versions: [
          ConflictVersion(
            versionId: 'v1',
            value: 'Value',
            authorId: 'user-1',
            modifiedAt: testDate,
          ),
        ],
        votes: {'user-2': 'v1'},
      );

      final model = ConflictModel.fromDomain(entity);

      expect(model.status, 'resolved');
      expect(model.versions.length, 1);
      expect(model.votes, {'user-2': 'v1'});
    });

    test('handles empty versions and votes from Firestore', () {
      final data = <String, dynamic>{
        'activityId': 'act-1',
        'fieldPath': 'title',
        'status': 'pending',
        'createdAt': testTimestamp,
        'votingDeadline': deadlineTimestamp,
        'resolvedAt': null,
        'resolutionMethod': null,
        'versions': null,
        'votes': null,
      };

      final model = ConflictModel.fromFirestore(data, 'c-1');

      expect(model.versions, isEmpty);
      expect(model.votes, isEmpty);
    });
  });
}
