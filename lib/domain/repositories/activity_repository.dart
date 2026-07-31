import '../entities/activity.dart';
import '../entities/timeline_entry.dart';
import 'params.dart';

/// Abstract repository for managing activities within the Kanban board.
abstract class ActivityRepository {
  /// Watches all activities belonging to a specific sector in real-time.
  Stream<List<Activity>> watchActivitiesBySector(String sectorId);

  /// Creates a new activity with the given parameters.
  Future<Activity> createActivity(CreateActivityParams params);

  /// Updates an existing activity's fields.
  Future<void> updateActivity(String activityId, UpdateActivityParams params);

  /// Moves an activity to a different Kanban state, updating the
  /// currentStateId, stateEnteredAt, and responsible users atomically.
  Future<void> moveActivity(
    String activityId,
    String targetStateId, {
    required DateTime stateEnteredAt,
    required List<String> responsibleUsers,
    required String movedBy,
  });

  /// Retrieves a single activity by its ID.
  Future<Activity> getActivity(String activityId);

  /// Adds a timeline entry recording a state transition for an activity.
  Future<void> addTimelineEntry(String activityId, TimelineEntry entry);

  /// Removes a user from the activity's responsible users list.
  Future<void> withdrawResponsibility(String activityId, String userId);
}
