import '../entities/activity_tracker_error.dart';

/// Result type for user profile validation.
sealed class UserValidationResult {
  const UserValidationResult();
}

/// Successful validation.
class UserValid extends UserValidationResult {
  final String email;
  final String nickname;
  final String sectorId;

  const UserValid({
    required this.email,
    required this.nickname,
    required this.sectorId,
  });
}

/// Failed validation containing the specific error.
class UserInvalid extends UserValidationResult {
  final ActivityTrackerError error;
  const UserInvalid(this.error);
}

/// Validates user profile fields according to business rules:
/// - Email must be a valid format and max 254 characters → [ActivityTrackerError.emailInvalid]
/// - Nickname must be 1–50 characters → [ActivityTrackerError.titleRequired]
/// - Sector must be specified (non-null, non-empty) → [ActivityTrackerError.sectorRequired]
/// - Email must be unique (case-insensitive) → [ActivityTrackerError.emailDuplicate]
class UserValidator {
  const UserValidator();

  /// Validates the user profile fields synchronously (without uniqueness check).
  ///
  /// Returns [UserValid] with normalized email (lowercased) and trimmed nickname,
  /// or [UserInvalid] with the appropriate error code.
  UserValidationResult validate({
    required String? email,
    required String? nickname,
    required String? sectorId,
  }) {
    // Validate email format
    if (email == null || !_isValidEmail(email)) {
      return const UserInvalid(ActivityTrackerError.emailInvalid);
    }

    // Validate nickname (1–50 characters, non-empty after trimming)
    if (nickname == null || nickname.trim().isEmpty) {
      return const UserInvalid(ActivityTrackerError.titleRequired);
    }
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.length > 50) {
      return const UserInvalid(ActivityTrackerError.titleRequired);
    }

    // Validate sector is specified
    if (sectorId == null || sectorId.trim().isEmpty) {
      return const UserInvalid(ActivityTrackerError.sectorRequired);
    }

    return UserValid(
      email: email.toLowerCase(),
      nickname: trimmedNickname,
      sectorId: sectorId.trim(),
    );
  }

  /// Validates user profile fields including async email uniqueness check.
  ///
  /// The [isEmailTaken] callback should perform a case-insensitive lookup
  /// to determine if the email is already registered.
  Future<UserValidationResult> validateWithUniqueness({
    required String? email,
    required String? nickname,
    required String? sectorId,
    required Future<bool> Function(String email) isEmailTaken,
  }) async {
    // First run synchronous validation
    final result = validate(email: email, nickname: nickname, sectorId: sectorId);
    if (result is UserInvalid) {
      return result;
    }

    final validResult = result as UserValid;

    // Check email uniqueness (case-insensitive via lowercased email)
    final taken = await isEmailTaken(validResult.email);
    if (taken) {
      return const UserInvalid(ActivityTrackerError.emailDuplicate);
    }

    return validResult;
  }

  /// Basic email format validation:
  /// - Non-empty local part and domain part separated by @
  /// - Domain contains at least one dot
  /// - Max 254 characters total
  bool _isValidEmail(String email) {
    if (email.isEmpty || email.length > 254) {
      return false;
    }

    final atIndex = email.lastIndexOf('@');
    if (atIndex <= 0) {
      return false;
    }

    final localPart = email.substring(0, atIndex);
    final domainPart = email.substring(atIndex + 1);

    // Local part must be non-empty
    if (localPart.isEmpty) {
      return false;
    }

    // Domain part must be non-empty and contain at least one dot
    if (domainPart.isEmpty || !domainPart.contains('.')) {
      return false;
    }

    // Domain part segments must be non-empty (no leading/trailing/consecutive dots)
    final domainSegments = domainPart.split('.');
    for (final segment in domainSegments) {
      if (segment.isEmpty) {
        return false;
      }
    }

    return true;
  }
}
