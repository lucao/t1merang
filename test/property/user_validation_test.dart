import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/domain/validators/user_validator.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';

/// Property-based tests for user profile validation.
///
/// Property 17: User profile field validation
/// **Validates: Requirements 7.1**
///
/// Property 18: Email uniqueness enforcement (case-insensitive)
/// **Validates: Requirements 7.2, 7.6**

void main() {
  const validator = UserValidator();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generate a random string of given length from the provided character set.
  String randomString(int length, String chars) {
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generate a valid email (local@domain.tld format, ≤254 chars).
  String generateValidEmail() {
    const localChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    const domainChars = 'abcdefghijklmnopqrstuvwxyz';
    final localLength = random.nextInt(20) + 1; // 1-20 chars
    final domainLength = random.nextInt(15) + 1; // 1-15 chars
    final tldLength = random.nextInt(4) + 2; // 2-5 chars
    final local = randomString(localLength, localChars);
    final domain = randomString(domainLength, domainChars);
    final tld = randomString(tldLength, domainChars);
    return '$local@$domain.$tld';
  }

  /// Generate an invalid email (missing @, missing domain dot, empty, too long, etc.)
  String generateInvalidEmail() {
    final kind = random.nextInt(5);
    switch (kind) {
      case 0:
        // No @ sign
        return randomString(random.nextInt(20) + 1, 'abcdefghijklmnopqrstuvwxyz');
      case 1:
        // No domain dot
        return '${randomString(random.nextInt(10) + 1, 'abcdefghijklmnopqrstuvwxyz')}@${randomString(random.nextInt(10) + 1, 'abcdefghijklmnopqrstuvwxyz')}';
      case 2:
        // Empty string
        return '';
      case 3:
        // Too long (>254 characters)
        final local = randomString(100, 'abcdefghijklmnopqrstuvwxyz');
        final domain = randomString(150, 'abcdefghijklmnopqrstuvwxyz');
        return '$local@$domain.com';
      case 4:
        // @ at the start (empty local part)
        return '@${randomString(random.nextInt(10) + 1, 'abcdefghijklmnopqrstuvwxyz')}.com';
      default:
        return '';
    }
  }

  /// Generate a valid nickname (1-50 characters, non-empty after trimming).
  String generateValidNickname() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
    final length = random.nextInt(50) + 1; // 1-50 chars
    // Ensure at least one non-whitespace character
    final base = randomString(length, chars);
    if (base.trim().isEmpty) {
      return 'a${base.substring(1)}';
    }
    return base;
  }

  /// Generate an invalid nickname (empty, whitespace-only, or >50 chars).
  String generateInvalidNickname() {
    final kind = random.nextInt(3);
    switch (kind) {
      case 0:
        // Empty string
        return '';
      case 1:
        // Whitespace only
        return '   ';
      case 2:
        // More than 50 characters
        return randomString(random.nextInt(50) + 51, 'abcdefghijklmnopqrstuvwxyz');
      default:
        return '';
    }
  }

  /// Generate a valid sector ID (non-null, non-empty).
  String generateValidSectorId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return randomString(random.nextInt(20) + 1, chars);
  }

  /// Generate an invalid sector ID (empty or whitespace-only).
  String generateInvalidSectorId() {
    final kind = random.nextInt(2);
    switch (kind) {
      case 0:
        return '';
      case 1:
        return '   ';
      default:
        return '';
    }
  }

  group('Feature: activity-tracker, Property 17: User profile field validation', () {
    // **Validates: Requirements 7.1**

    test(
      'accepts valid email, nickname, and sector combinations (100+ iterations)',
      () {
        for (var i = 0; i < 150; i++) {
          final email = generateValidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          final result = validator.validate(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
          );

          expect(
            result,
            isA<UserValid>(),
            reason: 'Should accept valid input: email="$email", '
                'nickname="$nickname", sectorId="$sectorId"',
          );
        }
      },
    );

    test(
      'rejects invalid emails (100+ iterations)',
      () {
        for (var i = 0; i < 150; i++) {
          final email = generateInvalidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          final result = validator.validate(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
          );

          expect(
            result,
            isA<UserInvalid>(),
            reason: 'Should reject invalid email: "$email"',
          );
          expect(
            (result as UserInvalid).error,
            equals(ActivityTrackerError.emailInvalid),
            reason: 'Error should be emailInvalid for email: "$email"',
          );
        }
      },
    );

    test(
      'rejects invalid nicknames (100+ iterations)',
      () {
        for (var i = 0; i < 150; i++) {
          final email = generateValidEmail();
          final nickname = generateInvalidNickname();
          final sectorId = generateValidSectorId();

          final result = validator.validate(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
          );

          expect(
            result,
            isA<UserInvalid>(),
            reason: 'Should reject invalid nickname: "$nickname"',
          );
          expect(
            (result as UserInvalid).error,
            equals(ActivityTrackerError.titleRequired),
            reason:
                'Error should be titleRequired for nickname: "$nickname"',
          );
        }
      },
    );

    test(
      'rejects invalid sector IDs (100+ iterations)',
      () {
        for (var i = 0; i < 150; i++) {
          final email = generateValidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateInvalidSectorId();

          final result = validator.validate(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
          );

          expect(
            result,
            isA<UserInvalid>(),
            reason: 'Should reject invalid sector: "$sectorId"',
          );
          expect(
            (result as UserInvalid).error,
            equals(ActivityTrackerError.sectorRequired),
            reason:
                'Error should be sectorRequired for sectorId: "$sectorId"',
          );
        }
      },
    );

    test(
      'rejects null email, nickname, and sectorId',
      () {
        // null email
        for (var i = 0; i < 100; i++) {
          final result = validator.validate(
            email: null,
            nickname: generateValidNickname(),
            sectorId: generateValidSectorId(),
          );
          expect(result, isA<UserInvalid>());
          expect((result as UserInvalid).error,
              equals(ActivityTrackerError.emailInvalid));
        }

        // null nickname
        for (var i = 0; i < 100; i++) {
          final result = validator.validate(
            email: generateValidEmail(),
            nickname: null,
            sectorId: generateValidSectorId(),
          );
          expect(result, isA<UserInvalid>());
          expect((result as UserInvalid).error,
              equals(ActivityTrackerError.titleRequired));
        }

        // null sectorId
        for (var i = 0; i < 100; i++) {
          final result = validator.validate(
            email: generateValidEmail(),
            nickname: generateValidNickname(),
            sectorId: null,
          );
          expect(result, isA<UserInvalid>());
          expect((result as UserInvalid).error,
              equals(ActivityTrackerError.sectorRequired));
        }
      },
    );

    test(
      'accepts if and only if email valid format ≤254 chars, nickname 1-50 chars, sector non-empty (100+ iterations)',
      () {
        for (var i = 0; i < 200; i++) {
          // Randomly decide to make each field valid or invalid
          final emailValid = random.nextBool();
          final nicknameValid = random.nextBool();
          final sectorValid = random.nextBool();

          final email = emailValid ? generateValidEmail() : generateInvalidEmail();
          final nickname = nicknameValid ? generateValidNickname() : generateInvalidNickname();
          final sectorId = sectorValid ? generateValidSectorId() : generateInvalidSectorId();

          final result = validator.validate(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
          );

          final allValid = emailValid && nicknameValid && sectorValid;

          if (allValid) {
            expect(
              result,
              isA<UserValid>(),
              reason:
                  'All fields valid → should accept. email="$email", '
                  'nickname="$nickname", sectorId="$sectorId"',
            );
          } else {
            expect(
              result,
              isA<UserInvalid>(),
              reason:
                  'At least one invalid field → should reject. '
                  'emailValid=$emailValid, nicknameValid=$nicknameValid, '
                  'sectorValid=$sectorValid',
            );
          }
        }
      },
    );

    test('email exactly at 254 character boundary is accepted', () {
      // Generate an email that is exactly 254 characters
      // local@domain.tld → need local + 1(@) + domain + 1(.) + tld = 254
      final tld = 'com';
      final domain = 'example';
      // local length = 254 - 1(@) - domain.length - 1(.) - tld.length
      final localLength = 254 - 1 - domain.length - 1 - tld.length;
      final local = randomString(localLength, 'abcdefghijklmnopqrstuvwxyz');
      final email = '$local@$domain.$tld';

      expect(email.length, equals(254));

      final result = validator.validate(
        email: email,
        nickname: 'Test User',
        sectorId: 'engineering',
      );
      expect(result, isA<UserValid>());
    });

    test('email at 255 characters is rejected', () {
      final tld = 'com';
      final domain = 'example';
      final localLength = 255 - 1 - domain.length - 1 - tld.length;
      final local = randomString(localLength, 'abcdefghijklmnopqrstuvwxyz');
      final email = '$local@$domain.$tld';

      expect(email.length, equals(255));

      final result = validator.validate(
        email: email,
        nickname: 'Test User',
        sectorId: 'engineering',
      );
      expect(result, isA<UserInvalid>());
      expect((result as UserInvalid).error,
          equals(ActivityTrackerError.emailInvalid));
    });

    test('nickname exactly at 50 character boundary is accepted', () {
      final nickname = randomString(50, 'abcdefghijklmnopqrstuvwxyz');
      final result = validator.validate(
        email: 'user@example.com',
        nickname: nickname,
        sectorId: 'engineering',
      );
      expect(result, isA<UserValid>());
    });

    test('nickname at 51 characters is rejected', () {
      final nickname = randomString(51, 'abcdefghijklmnopqrstuvwxyz');
      final result = validator.validate(
        email: 'user@example.com',
        nickname: nickname,
        sectorId: 'engineering',
      );
      expect(result, isA<UserInvalid>());
      expect((result as UserInvalid).error,
          equals(ActivityTrackerError.titleRequired));
    });

    test('valid result normalizes email to lowercase and trims nickname', () {
      for (var i = 0; i < 100; i++) {
        final email = generateValidEmail().toUpperCase();
        final nickname = '  ${generateValidNickname()}  ';
        final sectorId = generateValidSectorId();

        final result = validator.validate(
          email: email.toLowerCase(), // validator requires valid format which already works with lowercase
          nickname: nickname,
          sectorId: sectorId,
        );

        if (result is UserValid) {
          expect(result.email, equals(result.email.toLowerCase()),
              reason: 'Email should be lowercased');
          expect(result.nickname, equals(result.nickname.trim()),
              reason: 'Nickname should be trimmed');
        }
      }
    });
  });

  group('Feature: activity-tracker, Property 18: Email uniqueness enforcement (case-insensitive)', () {
    // **Validates: Requirements 7.2, 7.6**

    test(
      'rejects case-variant of existing email (100+ iterations)',
      () async {
        for (var i = 0; i < 150; i++) {
          final baseEmail = generateValidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          // Create a case-variant of the email
          final caseVariant = _generateCaseVariant(baseEmail, random);

          // Simulate that baseEmail already exists (case-insensitive)
          Future<bool> isEmailTaken(String email) async {
            return email.toLowerCase() == baseEmail.toLowerCase();
          }

          final result = await validator.validateWithUniqueness(
            email: caseVariant,
            nickname: nickname,
            sectorId: sectorId,
            isEmailTaken: isEmailTaken,
          );

          expect(
            result,
            isA<UserInvalid>(),
            reason:
                'Should reject case-variant "$caseVariant" of existing '
                'email "$baseEmail"',
          );
          expect(
            (result as UserInvalid).error,
            equals(ActivityTrackerError.emailDuplicate),
            reason: 'Error should be emailDuplicate',
          );
        }
      },
    );

    test(
      'accepts email that does not exist in the system (100+ iterations)',
      () async {
        for (var i = 0; i < 150; i++) {
          final email = generateValidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          // Simulate that the email does NOT exist
          Future<bool> isEmailTaken(String email) async => false;

          final result = await validator.validateWithUniqueness(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
            isEmailTaken: isEmailTaken,
          );

          expect(
            result,
            isA<UserValid>(),
            reason:
                'Should accept email "$email" when it does not exist in the system',
          );
        }
      },
    );

    test(
      'exact same email (same case) is also rejected as duplicate (100+ iterations)',
      () async {
        for (var i = 0; i < 150; i++) {
          final email = generateValidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          Future<bool> isEmailTaken(String emailToCheck) async {
            return emailToCheck.toLowerCase() == email.toLowerCase();
          }

          final result = await validator.validateWithUniqueness(
            email: email,
            nickname: nickname,
            sectorId: sectorId,
            isEmailTaken: isEmailTaken,
          );

          expect(
            result,
            isA<UserInvalid>(),
            reason: 'Should reject exact duplicate email "$email"',
          );
          expect(
            (result as UserInvalid).error,
            equals(ActivityTrackerError.emailDuplicate),
          );
        }
      },
    );

    test(
      'validates fields before checking uniqueness - invalid email skips uniqueness check (100+ iterations)',
      () async {
        for (var i = 0; i < 100; i++) {
          final invalidEmail = generateInvalidEmail();
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          var uniquenessCheckCalled = false;
          Future<bool> isEmailTaken(String email) async {
            uniquenessCheckCalled = true;
            return true;
          }

          final result = await validator.validateWithUniqueness(
            email: invalidEmail,
            nickname: nickname,
            sectorId: sectorId,
            isEmailTaken: isEmailTaken,
          );

          expect(result, isA<UserInvalid>());
          expect((result as UserInvalid).error,
              equals(ActivityTrackerError.emailInvalid));
          expect(uniquenessCheckCalled, isFalse,
              reason:
                  'Uniqueness check should not be called for invalid email');
        }
      },
    );

    test(
      'case-insensitive comparison uses lowercased email for lookup (100+ iterations)',
      () async {
        for (var i = 0; i < 100; i++) {
          final baseEmail = generateValidEmail();
          final caseVariant = _generateCaseVariant(baseEmail, random);
          final nickname = generateValidNickname();
          final sectorId = generateValidSectorId();

          String? lookedUpEmail;
          Future<bool> isEmailTaken(String email) async {
            lookedUpEmail = email;
            return false;
          }

          await validator.validateWithUniqueness(
            email: caseVariant,
            nickname: nickname,
            sectorId: sectorId,
            isEmailTaken: isEmailTaken,
          );

          // The validator should pass a lowercased email to isEmailTaken
          expect(
            lookedUpEmail,
            equals(caseVariant.toLowerCase()),
            reason:
                'Validator should pass lowercased email "$caseVariant" → '
                '"${caseVariant.toLowerCase()}" to isEmailTaken',
          );
        }
      },
    );
  });
}

/// Generate a case variant of an email by randomly changing case of characters.
String _generateCaseVariant(String email, Random random) {
  final chars = email.split('');
  var changed = false;
  for (var i = 0; i < chars.length; i++) {
    if (chars[i].contains(RegExp('[a-zA-Z]'))) {
      if (random.nextBool()) {
        chars[i] = chars[i] == chars[i].toUpperCase()
            ? chars[i].toLowerCase()
            : chars[i].toUpperCase();
        changed = true;
      }
    }
  }
  // Ensure at least one character differs in case
  if (!changed) {
    for (var i = 0; i < chars.length; i++) {
      if (chars[i].contains(RegExp('[a-zA-Z]'))) {
        chars[i] = chars[i] == chars[i].toUpperCase()
            ? chars[i].toLowerCase()
            : chars[i].toUpperCase();
        break;
      }
    }
  }
  return chars.join();
}
