import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/validators/title_validator.dart';

/// Feature: activity-tracker
/// Property 1: Title validation accepts and rejects correctly
///
/// **Validates: Requirements 1.1, 1.6, 2.2, 2.4**
///
/// For any string input, the title validation function SHALL accept the string
/// if and only if it is non-empty, not composed entirely of whitespace, and has
/// length between 1 and 200 characters (inclusive). All other strings SHALL be
/// rejected.

void main() {
  const validator = TitleValidator();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random string of the given [length] from [chars].
  String _randomString(int length, String chars) {
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a valid title: non-empty, not whitespace-only, 1-200 chars.
  /// At least one non-whitespace character is guaranteed.
  String generateValidTitle() {
    const nonWhitespaceChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+[]{}|;:,.<>?/~`';
    const allChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \t!@#\$%^&*()-_=+[]{}|;:,.<>?/~`';

    // Length between 1 and 200 (after trimming, must be 1-200)
    final length = random.nextInt(200) + 1;

    // Generate a string with at least one non-whitespace character
    final chars = List.generate(length, (_) {
      return allChars[random.nextInt(allChars.length)];
    });

    // Ensure at least one non-whitespace character
    final nonWsPos = random.nextInt(length);
    chars[nonWsPos] =
        nonWhitespaceChars[random.nextInt(nonWhitespaceChars.length)];

    final result = String.fromCharCodes(chars.map((c) => c.codeUnitAt(0)));

    // Verify after trim it's 1-200 chars and not all whitespace
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed.length > 200) {
      // Fallback to a simple valid title
      return _randomString(
        random.nextInt(200) + 1,
        nonWhitespaceChars,
      );
    }
    return result;
  }

  /// Generates an empty string (null handled separately).
  String generateEmptyTitle() {
    return '';
  }

  /// Generates a whitespace-only string of random length (1-300).
  String generateWhitespaceOnlyTitle() {
    const whitespaceChars = ' \t\n\r';
    final length = random.nextInt(300) + 1;
    return _randomString(length, whitespaceChars);
  }

  /// Generates a title that exceeds 200 characters after trimming.
  String generateTooLongTitle() {
    const nonWhitespaceChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    // Length between 201 and 500 (all non-whitespace so trim doesn't reduce it)
    final length = random.nextInt(300) + 201;
    return _randomString(length, nonWhitespaceChars);
  }

  group(
    'Feature: activity-tracker, Property 1: Title validation accepts and rejects correctly',
    () {
      test(
        'valid titles (non-empty, non-whitespace-only, 1-200 chars after trim) produce TitleValid',
        () {
          // Minimum 100 iterations
          for (var i = 0; i < 150; i++) {
            final title = generateValidTitle();
            final result = validator.validate(title);

            expect(
              result,
              isA<TitleValid>(),
              reason:
                  'Expected TitleValid for valid title (iteration $i): "${title.length > 50 ? '${title.substring(0, 50)}...' : title}" '
                  '(length=${title.length}, trimmed length=${title.trim().length})',
            );

            // Additionally verify the trimmed title is stored
            final valid = result as TitleValid;
            expect(valid.title, equals(title.trim()));
          }
        },
      );

      test(
        'null input produces TitleInvalid with titleRequired error',
        () {
          // Property: null input is always rejected
          for (var i = 0; i < 100; i++) {
            final result = validator.validate(null);

            expect(result, isA<TitleInvalid>());
            final invalid = result as TitleInvalid;
            expect(invalid.error, equals(ActivityTrackerError.titleRequired));
          }
        },
      );

      test(
        'empty string produces TitleInvalid with titleRequired error',
        () {
          for (var i = 0; i < 100; i++) {
            final title = generateEmptyTitle();
            final result = validator.validate(title);

            expect(result, isA<TitleInvalid>());
            final invalid = result as TitleInvalid;
            expect(invalid.error, equals(ActivityTrackerError.titleRequired));
          }
        },
      );

      test(
        'whitespace-only strings produce TitleInvalid with titleRequired error',
        () {
          for (var i = 0; i < 150; i++) {
            final title = generateWhitespaceOnlyTitle();
            final result = validator.validate(title);

            expect(
              result,
              isA<TitleInvalid>(),
              reason:
                  'Expected TitleInvalid for whitespace-only title (iteration $i): '
                  'length=${title.length}, repr="${title.replaceAll(' ', '·').replaceAll('\t', '→').replaceAll('\n', '↵').replaceAll('\r', '←')}"',
            );

            final invalid = result as TitleInvalid;
            expect(invalid.error, equals(ActivityTrackerError.titleRequired));
          }
        },
      );

      test(
        'titles exceeding 200 characters (after trim) produce TitleInvalid with titleTooLong error',
        () {
          for (var i = 0; i < 150; i++) {
            final title = generateTooLongTitle();
            final result = validator.validate(title);

            expect(
              result,
              isA<TitleInvalid>(),
              reason:
                  'Expected TitleInvalid for too-long title (iteration $i): '
                  'length=${title.length}, trimmed length=${title.trim().length}',
            );

            final invalid = result as TitleInvalid;
            expect(invalid.error, equals(ActivityTrackerError.titleTooLong));
          }
        },
      );

      test(
        'boundary: single non-whitespace character is valid (min length)',
        () {
          const chars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
          for (var i = 0; i < 100; i++) {
            final title = String.fromCharCode(
              chars.codeUnitAt(random.nextInt(chars.length)),
            );
            final result = validator.validate(title);

            expect(result, isA<TitleValid>());
            final valid = result as TitleValid;
            expect(valid.title, equals(title));
          }
        },
      );

      test(
        'boundary: exactly 200 non-whitespace characters is valid (max length)',
        () {
          const chars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
          for (var i = 0; i < 100; i++) {
            final title = _randomString(200, chars);
            final result = validator.validate(title);

            expect(
              result,
              isA<TitleValid>(),
              reason:
                  'Expected TitleValid for 200-char title (iteration $i)',
            );
            final valid = result as TitleValid;
            expect(valid.title.length, equals(200));
          }
        },
      );

      test(
        'boundary: exactly 201 non-whitespace characters is invalid',
        () {
          const chars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
          for (var i = 0; i < 100; i++) {
            final title = _randomString(201, chars);
            final result = validator.validate(title);

            expect(result, isA<TitleInvalid>());
            final invalid = result as TitleInvalid;
            expect(invalid.error, equals(ActivityTrackerError.titleTooLong));
          }
        },
      );

      test(
        'titles with leading/trailing whitespace but valid trimmed content produce TitleValid with trimmed value',
        () {
          const nonWhitespaceChars =
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
          for (var i = 0; i < 100; i++) {
            // Generate core content (1-190 chars to leave room for whitespace padding)
            final coreLength = random.nextInt(190) + 1;
            final core = _randomString(coreLength, nonWhitespaceChars);

            // Add random whitespace padding (won't cause trimmed length > 200)
            final leadingSpaces = ' ' * (random.nextInt(5) + 1);
            final trailingSpaces = ' ' * (random.nextInt(5) + 1);
            final title = '$leadingSpaces$core$trailingSpaces';

            final result = validator.validate(title);

            expect(
              result,
              isA<TitleValid>(),
              reason:
                  'Expected TitleValid for padded title (iteration $i): trimmed="${core.length > 30 ? '${core.substring(0, 30)}...' : core}"',
            );

            final valid = result as TitleValid;
            expect(valid.title, equals(core));
          }
        },
      );
    },
  );
}
