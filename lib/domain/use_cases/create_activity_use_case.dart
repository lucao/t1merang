import '../entities/activity.dart';
import '../entities/activity_tracker_error.dart';
import '../entities/permission.dart';
import '../repositories/access_control_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/params.dart';
import '../validators/title_validator.dart';

/// Result type for the CreateActivity use case.
sealed class CreateActivityResult {
  const CreateActivityResult();
}

/// Successful activity creation.
class CreateActivitySuccess extends CreateActivityResult {
  final Activity activity;
  const CreateActivitySuccess(this.activity);
}

/// Failed activity creation with a specific error.
class CreateActivityFailure extends CreateActivityResult {
  final ActivityTrackerError error;
  const CreateActivityFailure(this.error);
}

/// Use case for creating a new activity on the Kanban board.
///
/// Orchestrates:
/// 1. Title validation (non-empty, non-whitespace, 1–200 chars)
/// 2. Permission check (user must have Create permission)
/// 3. Delegates to [ActivityRepository] which assigns Backlog state,
///    sets the creator as responsible, initializes empty discussion/timeline,
///    and records creation timestamp in UTC with second precision.
class CreateActivityUseCase {
  final ActivityRepository _activityRepository;
  final AccessControlRepository _accessControlRepository;
  final TitleValidator _titleValidator;

  const CreateActivityUseCase({
    required ActivityRepository activityRepository,
    required AccessControlRepository accessControlRepository,
    TitleValidator titleValidator = const TitleValidator(),
  })  : _activityRepository = activityRepository,
        _accessControlRepository = accessControlRepository,
        _titleValidator = titleValidator;

  /// Executes the use case with the given [params].
  ///
  /// Returns [CreateActivitySuccess] with the created activity on success,
  /// or [CreateActivityFailure] with the appropriate error on failure.
  Future<CreateActivityResult> execute(CreateActivityParams params) async {
    // 1. Validate title
    final titleResult = _titleValidator.validate(params.title);
    if (titleResult is TitleInvalid) {
      return CreateActivityFailure(titleResult.error);
    }

    // 2. Check Create permission
    final permissions = await _accessControlRepository.getEffectivePermissions(
      params.createdBy,
      params.sectorId,
    );

    if (!permissions.contains(Permission.create)) {
      return const CreateActivityFailure(ActivityTrackerError.permissionDenied);
    }

    // 3. Create activity via repository
    // The repository is responsible for:
    // - Setting initial state to Backlog
    // - Assigning creator as responsible user
    // - Initializing empty discussion and timeline
    // - Recording creation timestamp in UTC with second precision
    final validTitle = (titleResult as TitleValid).title;
    final activity = await _activityRepository.createActivity(
      CreateActivityParams(
        title: validTitle,
        sectorId: params.sectorId,
        createdBy: params.createdBy,
      ),
    );

    return CreateActivitySuccess(activity);
  }
}
