import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/user_model.dart';
import 'package:activity_tracker/domain/entities/user_profile.dart';

void main() {
  group('UserModel', () {
    final testDate = DateTime.utc(2024, 1, 1, 0, 0, 0);
    final testTimestamp = Timestamp.fromDate(testDate);

    test('fromFirestore creates model from Firestore data', () {
      final data = <String, dynamic>{
        'email': 'user@example.com',
        'nickname': 'TestUser',
        'sectorId': 'sector-1',
        'createdAt': testTimestamp,
      };

      final model = UserModel.fromFirestore(data, 'user-1');

      expect(model.id, 'user-1');
      expect(model.email, 'user@example.com');
      expect(model.nickname, 'TestUser');
      expect(model.sectorId, 'sector-1');
      expect(model.createdAt, testDate);
    });

    test('toFirestore serializes model correctly', () {
      final model = UserModel(
        id: 'user-1',
        email: 'test@test.com',
        nickname: 'Nick',
        sectorId: 'sector-2',
        createdAt: testDate,
      );

      final data = model.toFirestore();

      expect(data['email'], 'test@test.com');
      expect(data['nickname'], 'Nick');
      expect(data['sectorId'], 'sector-2');
      expect(data['createdAt'], testTimestamp);
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts to UserProfile entity', () {
      final model = UserModel(
        id: 'user-1',
        email: 'user@example.com',
        nickname: 'TestUser',
        sectorId: 'sector-1',
        createdAt: testDate,
      );

      final entity = model.toDomain();

      expect(entity, isA<UserProfile>());
      expect(entity.id, 'user-1');
      expect(entity.email, 'user@example.com');
      expect(entity.nickname, 'TestUser');
      expect(entity.sectorId, 'sector-1');
    });

    test('fromDomain creates model from UserProfile entity', () {
      final entity = UserProfile(
        id: 'user-1',
        email: 'user@example.com',
        nickname: 'TestUser',
        sectorId: 'sector-1',
      );

      final model = UserModel.fromDomain(entity, createdAt: testDate);

      expect(model.id, 'user-1');
      expect(model.email, 'user@example.com');
      expect(model.nickname, 'TestUser');
      expect(model.sectorId, 'sector-1');
      expect(model.createdAt, testDate);
    });

    test('round-trip preserves profile data', () {
      final original = UserProfile(
        id: 'user-1',
        email: 'roundtrip@test.com',
        nickname: 'RoundTrip',
        sectorId: 'sector-5',
      );

      final model = UserModel.fromDomain(original, createdAt: testDate);
      final firestoreData = model.toFirestore();
      final restored = UserModel.fromFirestore(firestoreData, 'user-1');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
