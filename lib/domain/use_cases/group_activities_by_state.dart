import '../entities/activity.dart';
import '../entities/kanban_state.dart';
import '../entities/sort_order.dart';

/// Utility that groups activities by their current state into Kanban columns,
/// applies state-specific sorting, and filters out expired Production activities.
///
/// Behavior:
/// 1. Groups activities by [Activity.currentStateId] — each state becomes a column
/// 2. Sorts within each group by [Activity.stateEnteredAt] according to the
///    state's [KanbanState.sortOrder] (oldestFirst = ascending, newestFirst = descending)
/// 3. For states with [KanbanState.productionThresholdDays] set, filters out
///    activities whose stateEnteredAt is older than threshold days from [now]
///
/// Returns a [Map<String, List<Activity>>] keyed by stateId.
class GroupActivitiesByState {
  const GroupActivitiesByState();

  /// Executes the grouping, sorting, and filtering logic.
  ///
  /// [activities] — the full list of activities to group.
  /// [states] — the list of Kanban states defining columns.
  /// [now] — the current time used for threshold filtering (defaults to DateTime.now UTC).
  Map<String, List<Activity>> execute({
    required List<Activity> activities,
    required List<KanbanState> states,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();

    // Build a lookup from stateId -> KanbanState for fast access
    final stateMap = {for (final state in states) state.id: state};

    // Initialize result with empty lists for all known states
    final result = <String, List<Activity>>{
      for (final state in states) state.id: <Activity>[],
    };

    // Group activities by their currentStateId
    for (final activity in activities) {
      if (result.containsKey(activity.currentStateId)) {
        result[activity.currentStateId]!.add(activity);
      }
      // Activities with unknown stateIds are silently excluded
    }

    // Sort and filter each group
    for (final entry in result.entries) {
      final stateId = entry.key;
      final state = stateMap[stateId];
      var groupedActivities = entry.value;

      if (state == null) continue;

      // Filter by production threshold if configured
      if (state.productionThresholdDays != null) {
        final threshold = currentTime.subtract(
          Duration(days: state.productionThresholdDays!),
        );
        groupedActivities = groupedActivities
            .where((a) => !a.stateEnteredAt.isBefore(threshold))
            .toList();
      }

      // Sort by stateEnteredAt according to state's sortOrder
      groupedActivities.sort((a, b) {
        switch (state.sortOrder) {
          case SortOrder.oldestFirst:
            return a.stateEnteredAt.compareTo(b.stateEnteredAt);
          case SortOrder.newestFirst:
            return b.stateEnteredAt.compareTo(a.stateEnteredAt);
        }
      });

      result[stateId] = groupedActivities;
    }

    return result;
  }
}
