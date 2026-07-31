import 'dart:math';

import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/validators/state_validator.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Validates: Requirements 4.2, 4.3**
///
/// Property 10: State name validation and case-insensitive uniqueness
///
/// *For any* state name between 1 and 50 characters, creation SHALL succeed
/// if no existing state has a case-insensitive match. *For any* state name
/// that matches an existing state name (case-insensitive), creation SHALL be
/// rejected.
void main() {
  const validator = StateValidator();
  final random = Random(42); // Fixed seed for reproducibility

  // -- Generators --

  /// Generates a random string of the given [length] using printable ASCII characters.
  String randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-';
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a valid state name (1–50 non-whitespace-only characters).
  String generateValidName() {
    final length = random.nextInt(50) + 1; // 1 to 50
    String name;
    do {
      name = randomString(length);
    } while (name.trim().isEmpty); // Ensure non-whitespace-only
    return name;
  }

  /// Generates a list of unique existing state names (0–9 items).
  List<String> generateExistingStates(int count) {
    final states = <String>{};
    while (states.length < count) {
      final name = generateValidName();
      // Ensure case-insensitive uniqueness in the generated list
      if (!states.any((s) => s.toLowerCase() == name.trim().toLowerCase())) {
        states.add(name.trim());
      }
    }
    return states.toList();
  }

  /// Generates a case variant of the given [name] by randomly toggling case.
  String generateCaseVariant(String name) {
    return String.fromCharCodes(
      name.codeUnits.map((c) {
        if (c >= 65 && c <= 90) {
          // uppercase
          return random.nextBool() ? c + 32 : c;
        } else if (c >= 97 && c <= 122) {
          // lowercase
          return random.nextBool() ? c - 32 : c;
        }
        return c;
      }),
    );
  }

  group(
    'Feature: activity-tracker, Property 10: State name validation and case-insensitive uniqueness',
    () {
      test(
        'Valid unique names with <10 existing states are accepted',
        () {
          // For any state name between 1 and 50 characters, creation SHALL
          // succeed if no existing state has a case-insensitive match.
          for (var i = 0; i < 100; i++) {
            final existingCount = random.nextInt(10); // 0 to 9
            final existingStates = generateExistingStates(existingCount);
            String newName;
            // Generate a name that doesn't collide case-insensitively
            do {
              newName = generateValidName().trim();
            } while (existingStates
                .any((s) => s.toLowerCase() == newName.toLowerCase()));

            final result = validator.validate(newName, existingStates);

            expect(
              result,
              isA<StateValid>(),
              reason:
                  'Iteration $i: "$newName" should be accepted with ${existingStates.length} existing states: $existingStates',
            );
            expect(
              (result as StateValid).name,
              newName.trim(),
              reason: 'Result should contain the trimmed name',
            );
          }
        },
      );

      test(
        'Case-insensitive duplicates are rejected with stateNameDuplicate',
        () {
          // For any state name that matches an existing state name
          // (case-insensitive), creation SHALL be rejected.
          for (var i = 0; i < 100; i++) {
            final existingCount = random.nextInt(9) + 1; // 1 to 9
            final existingStates = generateExistingStates(existingCount);

            // Pick a random existing state and create a case variant
            final target = existingStates[random.nextInt(existingStates.length)];
            final variant = generateCaseVariant(target);

            final result = validator.validate(variant, existingStates);

            expect(
              result,
              isA<StateInvalid>(),
              reason:
                  'Iteration $i: "$variant" (variant of "$target") should be rejected',
            );
            expect(
              (result as StateInvalid).error,
              ActivityTrackerError.stateNameDuplicate,
              reason: 'Error should be stateNameDuplicate',
            );
          }
        },
      );

      test(
        'Names with >50 chars are rejected with titleRequired',
        () {
          for (var i = 0; i < 100; i++) {
            final length = 51 + random.nextInt(200); // 51 to 250 chars
            final longName = randomString(length);
            final existingStates = generateExistingStates(random.nextInt(10));

            final result = validator.validate(longName, existingStates);

            expect(
              result,
              isA<StateInvalid>(),
              reason:
                  'Iteration $i: Name of length $length should be rejected',
            );
            expect(
              (result as StateInvalid).error,
              ActivityTrackerError.titleRequired,
              reason: 'Error should be titleRequired for names >50 chars',
            );
          }
        },
      );

      test(
        'Empty or null names are rejected with titleRequired',
        () {
          for (var i = 0; i < 100; i++) {
            final existingStates = generateExistingStates(random.nextInt(10));

            // Test null
            final nullResult = validator.validate(null, existingStates);
            expect(nullResult, isA<StateInvalid>());
            expect(
              (nullResult as StateInvalid).error,
              ActivityTrackerError.titleRequired,
            );

            // Test empty string
            final emptyResult = validator.validate('', existingStates);
            expect(emptyResult, isA<StateInvalid>());
            expect(
              (emptyResult as StateInvalid).error,
              ActivityTrackerError.titleRequired,
            );

            // Test whitespace-only string
            final spaces = ' ' * (random.nextInt(10) + 1);
            final wsResult = validator.validate(spaces, existingStates);
            expect(wsResult, isA<StateInvalid>());
            expect(
              (wsResult as StateInvalid).error,
              ActivityTrackerError.titleRequired,
            );
          }
        },
      );

      test(
        '10 existing states are rejected with stateLimitReached',
        () {
          for (var i = 0; i < 100; i++) {
            final existingStates = generateExistingStates(10);
            final newName = generateValidName();

            final result = validator.validate(newName, existingStates);

            expect(
              result,
              isA<StateInvalid>(),
              reason:
                  'Iteration $i: Should be rejected when 10 states already exist',
            );
            expect(
              (result as StateInvalid).error,
              ActivityTrackerError.stateLimitReached,
              reason: 'Error should be stateLimitReached',
            );
          }
        },
      );
    },
  );
}
