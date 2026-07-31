import '../entities/activity_tracker_error.dart';
import '../entities/permission.dart';
import '../entities/timeline_entry.dart';
import '../repositories/access_control_repository.dart';
import '../repositories/activity_repository.dart';
import '../repositories/notification_repository.dart';

/// Parameters for moving an activity to a different state.
class MoveActivityParams {
  final String activityId;
  final String targetStateId;
  final String movedBy;

  const MoveActivityParams({
    required this.activityId,
    required this.targetStateId,
    required this.movedBy,
  });
}

/// Result of a successful move operation.
class MoveActivityResult {
  final String activityId;
  final String fromStateId;
  final String toStateId;
  final DateTime transitionedAt;
  final int durationMinutes;
  final List<String> responsibleUsers;

  const MoveActivityResult({
    required this.activityId,
    required this.fromStateId,
    required this.toStateId,
    required this.transitionedAt,
    required this.durationMinutes,
    required this.responsibleUsers,
  });
}

/// Use case for moving an activity from one Kanban state to another.
///
/// This use case:
/// 1. Checks Move permission for the user
/// 2. Retrieves the current activity
/// 3. Calculates duration spent in the previous state
/// 4. Adds the mover to responsible users if not already present
/// 5. Updates the activity state
/// 6. Records a timeline entry for the transition
/// 7. Sends notifications to all other responsible users
class MoveActivityUseCase {
  final ActivityRepository _activityRepository;
  final AccessControlRepository _accessControlRepository;
  final NotificationRepository _notificationRepository;
  final DateTime Function() _clock;

  MoveActivityUseCase({
    required ActivityRepository activityRepository,
    required AccessControlRepository accessControlRepository,
    required NotificationRepository notificationRepository,
    DateTime Function()? clock,
  })  : _activityRepository = activityRepository,
        _accessControlRepository = accessControlRepository,
        _notificationRepository = notificationRepository,
        _clock = clock ?? (() => DateTime.now().toUtc());

  /// Executes the move activity use case.
  ///
  /// Returns [MoveActivityResult] on success.
  /// Throws [ActivityTrackerError] on failure.
  Future<MoveActivityResult> execute(MoveActivityParams params) async {
    // 1. Check Move permission
    final activity = await _activityRepository.getActivity(params.activityId);
    final permissions = await _accessControlRepository.getEffectivePermissions(
      params.movedBy,
      activity.sectorId,
    );

    if (!permissions.contains(Permission.move)) {
      throw ActivityTrackerError.permissionDenied;
    }

    // 2. Calculate duration in previous state (floor division, minutes)
    final now = _clock();
    final durationSeconds =
        now.difference(activity.stateEnteredAt).inSeconds;
    final durationMinutes = durationSeconds ~/ 60;

    // 3. Add mover to responsible users if not already present
    final updatedResponsibleUsers =
        List<String>.from(activity.responsibleUsers);
    if (!updatedResponsibleUsers.contains(params.movedBy)) {
      updatedResponsibleUsers.add(params.movedBy);
    }

    // 4. Move the activity (update state, stateEnteredAt, responsibleUsers)
    await _activityRepository.moveActivity(
      params.activityId,
      params.targetStateId,
      stateEnteredAt: now,
      responsibleUsers: updatedResponsibleUsers,
      movedBy: params.movedBy,
    );

    // 5. Record timeline entry
    final timelineEntry = TimelineEntry(
      id: '', // Repository will assign ID
      fromStateId: activity.currentStateId,
      toStateId: params.targetStateId,
      transitionedAt: now,
      transitionedBy: params.movedBy,
      durationMinutes: durationMinutes,
    );

    await _activityRepository.addTimelineEntry(
      params.activityId,
      timelineEntry,
    );

    // 6. Send notifications to other responsible users
    final otherResponsibleUsers = updatedResponsibleUsers
        .where((userId) => userId != params.movedBy)
        .toList();

    for (final userId in otherResponsibleUsers) {
      await _notificationRepository.sendNotification(
        userId: userId,
        type: 'state_change',
        activityId: params.activityId,
        title: activity.title,
        body:
            'Activity "${activity.title}" moved from ${activity.currentStateId} to ${params.targetStateId}',
      );
    }

    return MoveActivityResult(
      activityId: params.activityId,
      fromStateId: activity.currentStateId,
      toStateId: params.targetStateId,
      transitionedAt: now,
      durationMinutes: durationMinutes,
      responsibleUsers: updatedResponsibleUsers,
    );
  }
}
