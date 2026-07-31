import '../entities/activity_tracker_error.dart';

/// Result type for state name validation.
sealed class StateValidationResult {
  const StateValidationResult();
}

/// Successful validation containing the trimmed state name.
class StateValid extends StateValidationResult {
  final String name;
  const StateValid(this.name);
}

/// Failed validation containing the specific error.
class StateInvalid extends StateValidationResult {
  final ActivityTrackerError error;
  const StateInvalid(this.error);
}

/// Validates state names according to business rules:
/// - Must not be null, empty, or whitespace-only → [ActivityTrackerError.titleRequired]
/// - Must not exceed 50 characters (after trimming) → [ActivityTrackerError.titleRequired]
/// - Must be unique case-insensitively among existing states → [ActivityTrackerError.stateNameDuplicate]
/// - Total states must not exceed 10 → [ActivityTrackerError.stateLimitReached]
class StateValidator {
  const StateValidator();

  /// Validates the given [name] against existing state names.
  ///
  /// [existingStateNames] is the list of current state names on the board.
  ///
  /// On success, returns [StateValid] with the trimmed name.
  /// On failure, returns [StateInvalid] with the appropriate error code.
  StateValidationResult validate(String? name, List<String> existingStateNames) {
    // Check state limit first (max 10 states per board)
    if (existingStateNames.length >= 10) {
      return const StateInvalid(ActivityTrackerError.stateLimitReached);
    }

    // Validate name is non-empty and not whitespace-only
    if (name == null || name.trim().isEmpty) {
      return const StateInvalid(ActivityTrackerError.titleRequired);
    }

    final trimmed = name.trim();

    // Validate name length (1–50 characters)
    if (trimmed.length > 50) {
      return const StateInvalid(ActivityTrackerError.titleRequired);
    }

    // Case-insensitive uniqueness check
    final lowerName = trimmed.toLowerCase();
    final isDuplicate = existingStateNames
        .any((existing) => existing.toLowerCase() == lowerName);

    if (isDuplicate) {
      return const StateInvalid(ActivityTrackerError.stateNameDuplicate);
    }

    return StateValid(trimmed);
  }
}
