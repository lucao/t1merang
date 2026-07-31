import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/validators/title_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = TitleValidator();

  group('TitleValidator', () {
    group('rejects with titleRequired', () {
      test('null input', () {
        final result = validator.validate(null);
        expect(result, isA<TitleInvalid>());
        expect((result as TitleInvalid).error,
            ActivityTrackerError.titleRequired);
      });

      test('empty string', () {
        final result = validator.validate('');
        expect(result, isA<TitleInvalid>());
        expect((result as TitleInvalid).error,
            ActivityTrackerError.titleRequired);
      });

      test('whitespace-only string', () {
        final result = validator.validate('   ');
        expect(result, isA<TitleInvalid>());
        expect((result as TitleInvalid).error,
            ActivityTrackerError.titleRequired);
      });

      test('tabs and newlines only', () {
        final result = validator.validate('\t\n\r ');
        expect(result, isA<TitleInvalid>());
        expect((result as TitleInvalid).error,
            ActivityTrackerError.titleRequired);
      });
    });

    group('rejects with titleTooLong', () {
      test('string with 201 characters after trimming', () {
        final result = validator.validate('a' * 201);
        expect(result, isA<TitleInvalid>());
        expect(
            (result as TitleInvalid).error, ActivityTrackerError.titleTooLong);
      });

      test('string with leading/trailing whitespace that exceeds 200 chars after trim', () {
        final result = validator.validate('  ${'a' * 201}  ');
        expect(result, isA<TitleInvalid>());
        expect(
            (result as TitleInvalid).error, ActivityTrackerError.titleTooLong);
      });
    });

    group('accepts valid titles', () {
      test('single character', () {
        final result = validator.validate('a');
        expect(result, isA<TitleValid>());
        expect((result as TitleValid).title, 'a');
      });

      test('exactly 200 characters', () {
        final title = 'a' * 200;
        final result = validator.validate(title);
        expect(result, isA<TitleValid>());
        expect((result as TitleValid).title, title);
      });

      test('typical title', () {
        final result = validator.validate('Fix login bug');
        expect(result, isA<TitleValid>());
        expect((result as TitleValid).title, 'Fix login bug');
      });

      test('trims leading and trailing whitespace', () {
        final result = validator.validate('  Hello World  ');
        expect(result, isA<TitleValid>());
        expect((result as TitleValid).title, 'Hello World');
      });

      test('title with internal whitespace preserved', () {
        final result = validator.validate('Hello   World');
        expect(result, isA<TitleValid>());
        expect((result as TitleValid).title, 'Hello   World');
      });
    });
  });
}
