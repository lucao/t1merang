import '../entities/activity_tracker_error.dart';

/// Result type for title validation.
sealed class TitleValidationResult {
  const TitleValidationResult();
}

/// Successful validation containing the trimmed title.
class TitleValid extends TitleValidationResult {
  final String title;
  const TitleValid(this.title);
}

/// Failed validation containing the specific error.
class TitleInvalid extends TitleValidationResult {
  final ActivityTrackerError error;
  const TitleInvalid(this.error);
}

/// Validates activity titles according to business rules:
/// - Must not be null, empty, or whitespace-only → [ActivityTrackerError.titleRequired]
/// - Must not exceed 200 characters (after trimming) → [ActivityTrackerError.titleTooLong]
class TitleValidator {
  const TitleValidator();

  /// Validates the given [title] and returns a [TitleValidationResult].
  ///
  /// On success, returns [TitleValid] with the trimmed title.
  /// On failure, returns [TitleInvalid] with the appropriate error code.
  TitleValidationResult validate(String? title) {
    if (title == null || title.trim().isEmpty) {
      return const TitleInvalid(ActivityTrackerError.titleRequired);
    }

    final trimmed = title.trim();

    if (trimmed.length > 200) {
      return const TitleInvalid(ActivityTrackerError.titleTooLong);
    }

    return TitleValid(trimmed);
  }
}
