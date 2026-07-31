import '../entities/activity_tracker_error.dart';
import '../repositories/activity_repository.dart';

/// Result of a withdraw responsibility operation.
sealed class WithdrawResponsibilityResult {
  const WithdrawResponsibilityResult();
}

class WithdrawResponsibilitySuccess extends WithdrawResponsibilityResult {
  const WithdrawResponsibilitySuccess();
}

class WithdrawResponsibilityFailure extends WithdrawResponsibilityResult {
  final ActivityTrackerError error;
  const WithdrawResponsibilityFailure(this.error);
}

/// Use case for withdrawing a user's responsibility from an activity.
///
/// Business rules:
/// - A user can only withdraw if they are in the responsible users list.
/// - If the user is the last responsible user, withdrawal is blocked
///   (at least one responsible user is always required).
/// - Otherwise, the user is removed from the responsibility list.
///
/// Requirements: 8.4, 8.5, 8.6
class WithdrawResponsibilityUseCase {
  final ActivityRepository _activityRepository;

  const WithdrawResponsibilityUseCase({
    required ActivityRepository activityRepository,
  }) : _activityRepository = activityRepository;

  /// Executes the withdrawal of [userId] from the responsible users
  /// of the activity identified by [activityId].
  Future<WithdrawResponsibilityResult> execute({
    required String activityId,
    required String userId,
  }) async {
    final activity = await _activityRepository.getActivity(activityId);

    // If the user is not in the responsible list, nothing to withdraw.
    if (!activity.responsibleUsers.contains(userId)) {
      return const WithdrawResponsibilitySuccess();
    }

    // Prevent withdrawal if user is the last responsible user.
    if (activity.responsibleUsers.length <= 1) {
      return const WithdrawResponsibilityFailure(
        ActivityTrackerError.withdrawalBlocked,
      );
    }

    // Remove the user from the responsibility list.
    await _activityRepository.withdrawResponsibility(activityId, userId);

    return const WithdrawResponsibilitySuccess();
  }
}
