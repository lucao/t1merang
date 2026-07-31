import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/domain/validators/post_validator.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';

/// Property-based tests for post validation.
///
/// **Feature: activity-tracker**
///
/// Uses random generation with minimum 100 iterations per property.
void main() {
  const validator = PostValidator();
  final random = Random(42); // Fixed seed for reproducibility

  // ─── Generators ───────────────────────────────────────────────────────────

  /// Generates a random string of exactly [length] characters.
  String generateString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?';
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a valid content string (1–2000 characters).
  String generateValidContent() {
    final length = random.nextInt(2000) + 1; // 1 to 2000
    return generateString(length);
  }

  /// Generates an invalid content string (empty or >2000 characters).
  String generateInvalidContent() {
    if (random.nextBool()) {
      // Empty string
      return '';
    } else {
      // Too long: 2001 to 3000 characters
      final length = 2001 + random.nextInt(1000);
      return generateString(length);
    }
  }

  /// Picks a random valid PostCategory.
  PostCategory generateValidCategory() {
    return PostCategory.values[random.nextInt(PostCategory.values.length)];
  }

  /// Generates a list of sector IDs with [count] elements.
  List<String> generateSectorIds(int count) {
    return List.generate(count, (i) => 'sector_${random.nextInt(1000)}_$i');
  }

  // ─── Property 14: Post content validation ─────────────────────────────────
  //
  // *For any* post submission, the system SHALL accept if and only if the
  // content is non-empty (between 1 and 2000 characters) and a valid category
  // (Information, Complaint, or Ask_Help) is selected.
  //
  // **Validates: Requirements 6.2, 6.6**

  group('Property 14: Post content validation', () {
    test(
      'accepts valid content (1–2000 chars) with a valid category',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final category = generateValidCategory();
          // For askHelp, provide valid target sectors so that doesn't interfere
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Valid content (length=${content.length}) and category=$category should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'rejects empty content regardless of category',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final category = generateValidCategory();
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: '',
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason: 'Empty content should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.postContentRequired),
          );
        }
      },
    );

    test(
      'rejects null content regardless of category',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final category = generateValidCategory();

          final result = validator.validate(
            content: null,
            category: category,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason: 'Null content should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.postContentRequired),
          );
        }
      },
    );

    test(
      'rejects content exceeding 2000 characters',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final length = 2001 + random.nextInt(1000); // 2001 to 3000
          final content = generateString(length);
          final category = generateValidCategory();
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Content exceeding 2000 chars (length=$length) should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.postContentRequired),
          );
        }
      },
    );

    test(
      'rejects null category even with valid content',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();

          final result = validator.validate(
            content: content,
            category: null,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Null category should be rejected even with valid content (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.postContentRequired),
          );
        }
      },
    );

    test(
      'boundary: content with exactly 1 character is accepted',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final content = generateString(1);
          final category = generateValidCategory();
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Content with exactly 1 character should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'boundary: content with exactly 2000 characters is accepted',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final content = generateString(2000);
          final category = generateValidCategory();
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Content with exactly 2000 characters should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'boundary: content with exactly 2001 characters is rejected',
      () {
        // **Validates: Requirements 6.2, 6.6**
        for (var i = 0; i < 100; i++) {
          final content = generateString(2001);
          final category = generateValidCategory();
          final targetSectors =
              category == PostCategory.askHelp ? generateSectorIds(random.nextInt(10) + 1) : null;

          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Content with exactly 2001 characters should be rejected (iteration $i)',
          );
        }
      },
    );
  });

  // ─── Property 15: Ask_Help post requires 1 to 10 target sectors ───────────
  //
  // *For any* post with category Ask_Help, the system SHALL accept if and only
  // if targetSectors contains between 1 and 10 sector IDs (inclusive).
  //
  // **Validates: Requirements 6.4, 6.8**

  group('Property 15: Ask_Help post requires 1 to 10 target sectors', () {
    test(
      'accepts Ask_Help post with 1 to 10 target sectors',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final sectorCount = random.nextInt(10) + 1; // 1 to 10
          final targetSectors = generateSectorIds(sectorCount);

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Ask_Help with $sectorCount target sectors should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'rejects Ask_Help post with null target sectors',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: null,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Ask_Help with null targetSectors should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.sectorRequired),
          );
        }
      },
    );

    test(
      'rejects Ask_Help post with empty target sectors list',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: [],
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Ask_Help with empty targetSectors should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.sectorRequired),
          );
        }
      },
    );

    test(
      'rejects Ask_Help post with more than 10 target sectors',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final sectorCount = 11 + random.nextInt(10); // 11 to 20
          final targetSectors = generateSectorIds(sectorCount);

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Ask_Help with $sectorCount target sectors (>10) should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.sectorRequired),
          );
        }
      },
    );

    test(
      'boundary: Ask_Help with exactly 1 target sector is accepted',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final targetSectors = generateSectorIds(1);

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Ask_Help with exactly 1 target sector should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'boundary: Ask_Help with exactly 10 target sectors is accepted',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final targetSectors = generateSectorIds(10);

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                'Ask_Help with exactly 10 target sectors should be accepted (iteration $i)',
          );
        }
      },
    );

    test(
      'boundary: Ask_Help with exactly 11 target sectors is rejected',
      () {
        // **Validates: Requirements 6.4, 6.8**
        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final targetSectors = generateSectorIds(11);

          final result = validator.validate(
            content: content,
            category: PostCategory.askHelp,
            targetSectors: targetSectors,
          );

          expect(
            result,
            isA<PostInvalid>(),
            reason:
                'Ask_Help with exactly 11 target sectors should be rejected (iteration $i)',
          );
          expect(
            (result as PostInvalid).error,
            equals(ActivityTrackerError.sectorRequired),
          );
        }
      },
    );

    test(
      'non-Ask_Help categories do not require target sectors',
      () {
        // **Validates: Requirements 6.4, 6.8**
        final nonAskHelpCategories = [
          PostCategory.information,
          PostCategory.complaint,
        ];

        for (var i = 0; i < 100; i++) {
          final content = generateValidContent();
          final category =
              nonAskHelpCategories[random.nextInt(nonAskHelpCategories.length)];

          // With null targetSectors - should still pass
          final result = validator.validate(
            content: content,
            category: category,
            targetSectors: null,
          );

          expect(
            result,
            isA<PostValid>(),
            reason:
                '$category post without targetSectors should be accepted (iteration $i)',
          );
        }
      },
    );
  });
}
