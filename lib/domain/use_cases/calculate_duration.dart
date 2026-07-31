import '../entities/timeline_entry.dart';

/// Utility for calculating timeline durations with minute-level precision.
///
/// All calculations use UTC timestamps with second precision.
/// Durations are expressed as integer minutes, with partial minutes
/// rounded down (floor).
class CalculateDuration {
  /// Calculates the duration in minutes between [entry] and [exit] timestamps.
  ///
  /// Returns `floor((exit - entry).inSeconds / 60)`.
  /// Both timestamps should be in UTC with second precision.
  int calculateDuration(DateTime entry, DateTime exit) {
    final differenceInSeconds = exit.difference(entry).inSeconds;
    return differenceInSeconds ~/ 60;
  }

  /// Aggregates cumulative time per state from a list of timeline entries.
  ///
  /// Returns a `Map<String, int>` mapping each stateId to the total minutes
  /// spent in that state. The aggregation sums `durationMinutes` for all
  /// entries where `fromStateId` matches the state.
  Map<String, int> aggregateTimePerState(List<TimelineEntry> entries) {
    final result = <String, int>{};
    for (final entry in entries) {
      result.update(
        entry.fromStateId,
        (current) => current + entry.durationMinutes,
        ifAbsent: () => entry.durationMinutes,
      );
    }
    return result;
  }

  /// Calculates the elapsed time in the current state.
  ///
  /// Returns `floor((now - stateEnteredAt).inSeconds / 60)` as integer minutes.
  int calculateCurrentStateElapsed(DateTime stateEnteredAt, DateTime now) {
    final differenceInSeconds = now.difference(stateEnteredAt).inSeconds;
    return differenceInSeconds ~/ 60;
  }
}
