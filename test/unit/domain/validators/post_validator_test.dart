import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/validators/post_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = PostValidator();

  group('PostValidator', () {
    group('rejects with postContentRequired', () {
      test('null content', () {
        final result = validator.validate(
          content: null,
          category: PostCategory.information,
        );
        expect(result, isA<PostInvalid>());
        expect((result as PostInvalid).error,
            ActivityTrackerError.postContentRequired);
      });

      test('empty content', () {
        final result = validator.validate(
          content: '',
          category: PostCategory.information,
        );
        expect(result, isA<PostInvalid>());
        expect((result as PostInvalid).error,
            ActivityTrackerError.postContentRequired);
      });

      test('content exceeding 2000 characters', () {
        final result = validator.validate(
          content: 'a' * 2001,
          category: PostCategory.information,
        );
        expect(result, isA<PostInvalid>());
        expect((result as PostInvalid).error,
            ActivityTrackerError.postContentRequired);
      });

      test('null category', () {
        final result = validator.validate(
          content: 'Valid content',
          category: null,
        );
        expect(result, isA<PostInvalid>());
        expect((result as PostInvalid).error,
            ActivityTrackerError.postContentRequired);
      });
    });

    group('rejects with sectorRequired', () {
      test('askHelp with null targetSectors', () {
        final result = validator.validate(
          content: 'Need help',
          category: PostCategory.askHelp,
          targetSectors: null,
        );
        expect(result, isA<PostInvalid>());
        expect(
            (result as PostInvalid).error, ActivityTrackerError.sectorRequired);
      });

      test('askHelp with empty targetSectors', () {
        final result = validator.validate(
          content: 'Need help',
          category: PostCategory.askHelp,
          targetSectors: [],
        );
        expect(result, isA<PostInvalid>());
        expect(
            (result as PostInvalid).error, ActivityTrackerError.sectorRequired);
      });

      test('askHelp with more than 10 targetSectors', () {
        final result = validator.validate(
          content: 'Need help',
          category: PostCategory.askHelp,
          targetSectors: List.generate(11, (i) => 'sector_$i'),
        );
        expect(result, isA<PostInvalid>());
        expect(
            (result as PostInvalid).error, ActivityTrackerError.sectorRequired);
      });
    });

    group('accepts valid posts', () {
      test('information post with valid content', () {
        final result = validator.validate(
          content: 'This is an update',
          category: PostCategory.information,
        );
        expect(result, isA<PostValid>());
        final valid = result as PostValid;
        expect(valid.content, 'This is an update');
        expect(valid.category, PostCategory.information);
        expect(valid.targetSectors, isNull);
      });

      test('complaint post with valid content', () {
        final result = validator.validate(
          content: 'Something is wrong',
          category: PostCategory.complaint,
        );
        expect(result, isA<PostValid>());
        final valid = result as PostValid;
        expect(valid.content, 'Something is wrong');
        expect(valid.category, PostCategory.complaint);
      });

      test('askHelp post with 1 target sector', () {
        final result = validator.validate(
          content: 'Need assistance',
          category: PostCategory.askHelp,
          targetSectors: ['engineering'],
        );
        expect(result, isA<PostValid>());
        final valid = result as PostValid;
        expect(valid.content, 'Need assistance');
        expect(valid.category, PostCategory.askHelp);
        expect(valid.targetSectors, ['engineering']);
      });

      test('askHelp post with 10 target sectors', () {
        final sectors = List.generate(10, (i) => 'sector_$i');
        final result = validator.validate(
          content: 'Need cross-team help',
          category: PostCategory.askHelp,
          targetSectors: sectors,
        );
        expect(result, isA<PostValid>());
        final valid = result as PostValid;
        expect(valid.targetSectors, hasLength(10));
      });

      test('content with exactly 1 character', () {
        final result = validator.validate(
          content: 'x',
          category: PostCategory.information,
        );
        expect(result, isA<PostValid>());
      });

      test('content with exactly 2000 characters', () {
        final result = validator.validate(
          content: 'a' * 2000,
          category: PostCategory.information,
        );
        expect(result, isA<PostValid>());
      });

      test('non-askHelp post ignores targetSectors', () {
        final result = validator.validate(
          content: 'Info post',
          category: PostCategory.information,
          targetSectors: ['sector1', 'sector2'],
        );
        expect(result, isA<PostValid>());
        final valid = result as PostValid;
        expect(valid.targetSectors, ['sector1', 'sector2']);
      });
    });
  });
}
