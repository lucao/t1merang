import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/post_model.dart';
import 'package:activity_tracker/domain/entities/post.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';

void main() {
  group('PostModel', () {
    final testDate = DateTime.utc(2024, 3, 10, 14, 0, 0);
    final testTimestamp = Timestamp.fromDate(testDate);

    test('fromFirestore creates model for Information post', () {
      final data = <String, dynamic>{
        'content': 'This is an informational post.',
        'category': 'Information',
        'authorId': 'user-1',
        'createdAt': testTimestamp,
      };

      final model = PostModel.fromFirestore(data, 'post-1');

      expect(model.id, 'post-1');
      expect(model.content, 'This is an informational post.');
      expect(model.category, 'Information');
      expect(model.authorId, 'user-1');
      expect(model.createdAt, testDate);
      expect(model.targetSectors, null);
    });

    test('fromFirestore creates model for Ask_Help post with targetSectors', () {
      final data = <String, dynamic>{
        'content': 'Need help with this task.',
        'category': 'Ask_Help',
        'authorId': 'user-2',
        'createdAt': testTimestamp,
        'targetSectors': ['sector-1', 'sector-2'],
      };

      final model = PostModel.fromFirestore(data, 'post-2');

      expect(model.category, 'Ask_Help');
      expect(model.targetSectors, ['sector-1', 'sector-2']);
    });

    test('toFirestore serializes correctly without targetSectors', () {
      final model = PostModel(
        id: 'post-1',
        content: 'Test content',
        category: 'Complaint',
        authorId: 'user-1',
        createdAt: testDate,
      );

      final data = model.toFirestore();

      expect(data['content'], 'Test content');
      expect(data['category'], 'Complaint');
      expect(data['authorId'], 'user-1');
      expect(data['createdAt'], testTimestamp);
      expect(data.containsKey('targetSectors'), false);
      expect(data.containsKey('id'), false);
    });

    test('toFirestore includes targetSectors when present', () {
      final model = PostModel(
        id: 'post-2',
        content: 'Help needed',
        category: 'Ask_Help',
        authorId: 'user-1',
        createdAt: testDate,
        targetSectors: ['sector-a'],
      );

      final data = model.toFirestore();

      expect(data['targetSectors'], ['sector-a']);
    });

    test('toDomain converts category strings to enum values', () {
      final informationModel = PostModel(
        id: 'p1',
        content: 'c',
        category: 'Information',
        authorId: 'u',
        createdAt: testDate,
      );
      expect(informationModel.toDomain().category, PostCategory.information);

      final complaintModel = PostModel(
        id: 'p2',
        content: 'c',
        category: 'Complaint',
        authorId: 'u',
        createdAt: testDate,
      );
      expect(complaintModel.toDomain().category, PostCategory.complaint);

      final askHelpModel = PostModel(
        id: 'p3',
        content: 'c',
        category: 'Ask_Help',
        authorId: 'u',
        createdAt: testDate,
      );
      expect(askHelpModel.toDomain().category, PostCategory.askHelp);
    });

    test('fromDomain converts enum values to category strings', () {
      final entity = Post(
        id: 'post-1',
        content: 'Test',
        category: PostCategory.askHelp,
        authorId: 'user-1',
        createdAt: testDate,
        targetSectors: ['sector-1'],
      );

      final model = PostModel.fromDomain(entity);

      expect(model.category, 'Ask_Help');
      expect(model.targetSectors, ['sector-1']);
    });

    test('round-trip preserves all fields', () {
      final original = Post(
        id: 'post-1',
        content: 'Round trip post',
        category: PostCategory.complaint,
        authorId: 'user-3',
        createdAt: testDate,
        targetSectors: null,
      );

      final model = PostModel.fromDomain(original);
      final firestoreData = model.toFirestore();
      final restored = PostModel.fromFirestore(firestoreData, 'post-1');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
