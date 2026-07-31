import '../entities/activity.dart';
import '../entities/activity_tracker_error.dart';
import '../entities/permission.dart';
import '../repositories/access_control_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/params.dart';
import '../validators/title_validator.dart';

/// Result type for the UpdateActivityTitle use case.
sealed class UpdateActivityTitleResult {
  const UpdateActivityTitleResult();
}

/// Successful title update containing the updated activity.
class UpdateActivityTitleSuccess extends UpdateActivityTitleResult {
  final Activity activity;
  const UpdateActivityTitleSuccess(this.activity);
}

/// Failed title update containing the specific error.
class UpdateActivityTitleFailure extends UpdateActivityTitleResult {
  final ActivityTrackerError error;
  const UpdateActivityTitleFailure(this.error);
}

/// Use case for updating an activity's title.
///
/// Validates the new title, checks Modify permission, ensures no conflict
/// is in progress, and persists the change with the modifying user's identity.
class UpdateActivityTitleUseCase {
  final ActivityRepository _activityRepository;
  final AccessControlRepository _accessControlRepository;
  final TitleValidator _titleValidator;

  const UpdateActivityTitleUseCase({
    required ActivityRepository activityRepository,
    required AccessControlRepository accessControlRepository,
    TitleValidator titleValidator = const TitleValidator(),
  })  : _activityRepository = activityRepository,
        _accessControlRepository = accessControlRepository,
        _titleValidator = titleValidator;

  /// Executes the update activity title use case.
  ///
  /// Parameters:
  /// - [activityId]: The ID of the activity to update.
  /// - [newTitle]: The new title value.
  /// - [userId]: The ID of the user performing the modification.
  /// - [sectorId]: The sector ID for permission checking.
  ///
  /// Returns [UpdateActivityTitleSuccess] with the updated activity on success,
  /// or [UpdateActivityTitleFailure] with the appropriate error on failure.
  Future<UpdateActivityTitleResult> call({
    required String activityId,
    required String newTitle,
    required String userId,
    required String sectorId,
  }) async {
    // 1. Validate the new title
    final validationResult = _titleValidator.validate(newTitle);
    switch (validationResult) {
      case TitleInvalid(:final error):
        return UpdateActivityTitleFailure(error);
      case TitleValid():
        break;
    }

    // 2. Check Modify permission
    final permissions = await _accessControlRepository.getEffectivePermissions(
      userId,
      sectorId,
    );
    if (!permissions.contains(Permission.modify)) {
      return const UpdateActivityTitleFailure(
        ActivityTrackerError.permissionDenied,
      );
    }

    // 3. Retrieve the activity and check conflict lock
    final activity = await _activityRepository.getActivity(activityId);
    if (activity.isConflicted) {
      return const UpdateActivityTitleFailure(
        ActivityTrackerError.conflictInProgress,
      );
    }

    // 4. Persist the title change with modifying user identity
    final validTitle = (validationResult as TitleValid).title;
    await _activityRepository.updateActivity(
      activityId,
      UpdateActivityParams(
        title: validTitle,
        modifiedBy: userId,
      ),
    );

    // 5. Return the updated activity
    final updatedActivity = await _activityRepository.getActivity(activityId);
    return UpdateActivityTitleSuccess(updatedActivity);
  }
}
