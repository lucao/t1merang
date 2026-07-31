import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/kanban_state.dart';
import 'package:activity_tracker/domain/entities/sort_order.dart';
import 'package:activity_tracker/domain/use_cases/group_activities_by_state.dart';

/// Feature: activity-tracker
/// Property 3: Activities are grouped into correct state columns
///
/// **Validates: Requirements 2.3**
///
/// For any list of activities with varying currentStateId values, the Kanban
/// grouping function SHALL produce a mapping where each activity appears exactly
/// once, in the column matching its currentStateId.
///
/// ---
///
/// Feature: activity-tracker
/// Property 11: State-specific activity sorting and threshold filtering
///
/// **Validates: Requirements 4.5, 4.6, 4.7**
///
/// For any list of activities within a state, the sort function SHALL order
/// activities according to the state's configured sort order (oldest-first or
/// newest-first by stateEnteredAt). Additionally, for Production-type states,
/// for any threshold value T, the filter SHALL exclude activities whose
/// stateEnteredAt is older than T days from the current time.

void main() {
  const groupActivitiesByState = GroupActivitiesByState();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random alphanumeric ID of the given [length].
  String _randomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a random DateTime within a range of [daysBack] from [reference].
  DateTime _randomDateTime(DateTime reference, int daysBack) {
    final offsetSeconds = random.nextInt(daysBack * 24 * 60 * 60);
    return reference.subtract(Duration(seconds: offsetSeconds));
  }

  /// Generates a list of KanbanState objects with random configurations.
  List<KanbanState> generateStates({int? count}) {
    final stateCount = count ?? (random.nextInt(5) + 2); // 2-6 states
    return List.generate(stateCount, (i) {
      final sortOrder =
          random.nextBool() ? SortOrder.oldestFirst : SortOrder.newestFirst;
      final hasThreshold = random.nextBool();
      return KanbanState(
        id: 'state_$i',
        name: 'State $i',
        order: i,
        sortOrder: sortOrder,
        isDefault: i < 3,
        productionThresholdDays: hasThreshold ? random.nextInt(365) + 1 : null,
      );
    });
  }

  /// Generates a list of Activity objects assigned to random states from [stateIds].
  List<Activity> generateActivities({
    required List<String> stateIds,
    int? count,
    DateTime? referenceTime,
  }) {
    final activityCount = count ?? (random.nextInt(30) + 5); // 5-34 activities
    final now = referenceTime ?? DateTime.utc(2025, 6, 15);
    return List.generate(activityCount, (i) {
      final stateId = stateIds[random.nextInt(stateIds.length)];
      return Activity(
        id: 'activity_${_randomId(6)}_$i',
        title: 'Activity $i',
        currentStateId: stateId,
        sectorId: 'sector_1',
        createdAt: _randomDateTime(now, 120),
        createdBy: 'user_1',
        lastModifiedAt: _randomDateTime(now, 60),
        lastModifiedBy: 'user_1',
        stateEnteredAt: _randomDateTime(now, 90),
        responsibleUsers: const ['user_1'],
        isConflicted: false,
        version: 1,
      );
    });
  }

  // =====================================================================
  // Property 3: Activities are grouped into correct state columns
  // =====================================================================
  group(
    'Feature: activity-tracker, Property 3: Activities are grouped into correct state columns',
    () {
      test(
        'each activity appears exactly once, in the column matching its currentStateId',
        () {
          for (var i = 0; i < 150; i++) {
            final states = generateStates();
            final stateIds = states.map((s) => s.id).toList();
            final activities = generateActivities(stateIds: stateIds);

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: states,
            );

            // 1. Result has an entry for every defined state
            for (final state in states) {
              expect(
                result.containsKey(state.id),
                isTrue,
                reason:
                    'Iteration $i: Result should contain key for state "${state.id}"',
              );
            }

            // 2. Each activity appears exactly once across all columns
            final allGroupedActivities =
                result.values.expand((list) => list).toList();

            // Collect all activities that should be present (those with known stateIds)
            final activitiesWithKnownState = activities
                .where((a) => stateIds.contains(a.currentStateId))
                .toList();

            // Without production threshold filtering, every activity with a known
            // state should appear. With filtering, some may be excluded — but
            // those that DO appear must be in the correct column.
            // Let's verify placement correctness for all that appear:
            for (final entry in result.entries) {
              final stateId = entry.key;
              for (final activity in entry.value) {
                expect(
                  activity.currentStateId,
                  equals(stateId),
                  reason:
                      'Iteration $i: Activity "${activity.id}" is in column "$stateId" '
                      'but has currentStateId "${activity.currentStateId}"',
                );
              }
            }

            // 3. No activity appears in multiple columns (uniqueness)
            final activityIds = allGroupedActivities.map((a) => a.id).toList();
            expect(
              activityIds.length,
              equals(activityIds.toSet().length),
              reason:
                  'Iteration $i: Some activities appear in multiple columns',
            );

            // 4. Every activity with a known stateId that passes threshold filtering
            //    must appear in the result. Verify by checking that activities NOT
            //    in the result are only those filtered out by threshold.
            for (final activity in activitiesWithKnownState) {
              final state =
                  states.firstWhere((s) => s.id == activity.currentStateId);
              if (state.productionThresholdDays != null) {
                // Activity might have been filtered — if it's not in the
                // result, we verify it was correctly excluded
                if (!activityIds.contains(activity.id)) {
                  // It was filtered — that's the threshold's job, tested in Property 11
                }
              } else {
                // No threshold — activity MUST be in result
                expect(
                  activityIds.contains(activity.id),
                  isTrue,
                  reason:
                      'Iteration $i: Activity "${activity.id}" with state "${activity.currentStateId}" '
                      'should appear in result (no threshold filtering for this state)',
                );
              }
            }
          }
        },
      );

      test(
        'activities with unknown stateIds are excluded from all columns',
        () {
          for (var i = 0; i < 100; i++) {
            final states = generateStates(count: 3);
            final stateIds = states.map((s) => s.id).toList();

            // Generate some activities with known states and some with unknown states
            final knownActivities = generateActivities(
              stateIds: stateIds,
              count: random.nextInt(10) + 3,
            );
            final unknownActivities = List.generate(
              random.nextInt(5) + 1,
              (j) => Activity(
                id: 'unknown_$j',
                title: 'Unknown $j',
                currentStateId: 'nonexistent_state_$j',
                sectorId: 'sector_1',
                createdAt: DateTime.utc(2025, 1, 1),
                createdBy: 'user_1',
                lastModifiedAt: DateTime.utc(2025, 1, 1),
                lastModifiedBy: 'user_1',
                stateEnteredAt: DateTime.utc(2025, 1, 1),
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              ),
            );

            final allActivities = [...knownActivities, ...unknownActivities];

            final result = groupActivitiesByState.execute(
              activities: allActivities,
              states: states,
            );

            // Unknown activities should not appear in any column
            final allGroupedIds =
                result.values.expand((list) => list).map((a) => a.id).toSet();
            for (final unknown in unknownActivities) {
              expect(
                allGroupedIds.contains(unknown.id),
                isFalse,
                reason:
                    'Iteration $i: Activity "${unknown.id}" with unknown state '
                    'should not appear in any column',
              );
            }
          }
        },
      );

      test(
        'empty activity list produces empty columns for all states',
        () {
          for (var i = 0; i < 100; i++) {
            final states = generateStates();

            final result = groupActivitiesByState.execute(
              activities: [],
              states: states,
            );

            for (final state in states) {
              expect(
                result[state.id],
                isEmpty,
                reason:
                    'Iteration $i: Column "${state.id}" should be empty for empty input',
              );
            }
          }
        },
      );
    },
  );

  // =====================================================================
  // Property 11: State-specific activity sorting and threshold filtering
  // =====================================================================
  group(
    'Feature: activity-tracker, Property 11: State-specific activity sorting and threshold filtering',
    () {
      test(
        'activities in oldestFirst states are sorted ascending by stateEnteredAt',
        () {
          for (var i = 0; i < 150; i++) {
            final now = DateTime.utc(2025, 6, 15);
            final state = KanbanState(
              id: 'state_oldest',
              name: 'Backlog',
              order: 0,
              sortOrder: SortOrder.oldestFirst,
              isDefault: true,
              productionThresholdDays: null,
            );

            final activityCount = random.nextInt(20) + 2;
            final activities = List.generate(activityCount, (j) {
              return Activity(
                id: 'activity_$j',
                title: 'Activity $j',
                currentStateId: state.id,
                sectorId: 'sector_1',
                createdAt: _randomDateTime(now, 120),
                createdBy: 'user_1',
                lastModifiedAt: _randomDateTime(now, 60),
                lastModifiedBy: 'user_1',
                stateEnteredAt: _randomDateTime(now, 90),
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              );
            });

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: [state],
              now: now,
            );

            final sorted = result[state.id]!;

            // Verify ascending order by stateEnteredAt
            for (var j = 0; j < sorted.length - 1; j++) {
              expect(
                sorted[j].stateEnteredAt.compareTo(sorted[j + 1].stateEnteredAt) <= 0,
                isTrue,
                reason:
                    'Iteration $i: Activities should be sorted oldest-first. '
                    'Index $j (${sorted[j].stateEnteredAt}) should be <= index ${j + 1} (${sorted[j + 1].stateEnteredAt})',
              );
            }
          }
        },
      );

      test(
        'activities in newestFirst states are sorted descending by stateEnteredAt',
        () {
          for (var i = 0; i < 150; i++) {
            final now = DateTime.utc(2025, 6, 15);
            final state = KanbanState(
              id: 'state_newest',
              name: 'Development',
              order: 1,
              sortOrder: SortOrder.newestFirst,
              isDefault: true,
              productionThresholdDays: null,
            );

            final activityCount = random.nextInt(20) + 2;
            final activities = List.generate(activityCount, (j) {
              return Activity(
                id: 'activity_$j',
                title: 'Activity $j',
                currentStateId: state.id,
                sectorId: 'sector_1',
                createdAt: _randomDateTime(now, 120),
                createdBy: 'user_1',
                lastModifiedAt: _randomDateTime(now, 60),
                lastModifiedBy: 'user_1',
                stateEnteredAt: _randomDateTime(now, 90),
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              );
            });

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: [state],
              now: now,
            );

            final sorted = result[state.id]!;

            // Verify descending order by stateEnteredAt
            for (var j = 0; j < sorted.length - 1; j++) {
              expect(
                sorted[j].stateEnteredAt.compareTo(sorted[j + 1].stateEnteredAt) >= 0,
                isTrue,
                reason:
                    'Iteration $i: Activities should be sorted newest-first. '
                    'Index $j (${sorted[j].stateEnteredAt}) should be >= index ${j + 1} (${sorted[j + 1].stateEnteredAt})',
              );
            }
          }
        },
      );

      test(
        'production threshold filters out activities older than T days',
        () {
          for (var i = 0; i < 150; i++) {
            final now = DateTime.utc(2025, 6, 15);
            final thresholdDays = random.nextInt(60) + 1; // 1-60 days

            final state = KanbanState(
              id: 'state_production',
              name: 'Production',
              order: 2,
              sortOrder: SortOrder.newestFirst,
              isDefault: true,
              productionThresholdDays: thresholdDays,
            );

            final threshold = now.subtract(Duration(days: thresholdDays));

            // Generate a mix of activities: some within threshold, some outside
            final activityCount = random.nextInt(20) + 5;
            final activities = List.generate(activityCount, (j) {
              // Half within threshold, half outside
              final withinThreshold = j % 2 == 0;
              DateTime stateEnteredAt;
              if (withinThreshold) {
                // Within threshold: between threshold and now
                final offsetSeconds =
                    random.nextInt(thresholdDays * 24 * 60 * 60);
                stateEnteredAt = now.subtract(Duration(seconds: offsetSeconds));
                // Make sure it's not before threshold
                if (stateEnteredAt.isBefore(threshold)) {
                  stateEnteredAt = threshold.add(const Duration(hours: 1));
                }
              } else {
                // Outside threshold: older than threshold
                final extraDays = random.nextInt(90) + 1;
                stateEnteredAt =
                    threshold.subtract(Duration(days: extraDays));
              }

              return Activity(
                id: 'activity_$j',
                title: 'Activity $j',
                currentStateId: state.id,
                sectorId: 'sector_1',
                createdAt: _randomDateTime(now, 200),
                createdBy: 'user_1',
                lastModifiedAt: _randomDateTime(now, 60),
                lastModifiedBy: 'user_1',
                stateEnteredAt: stateEnteredAt,
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              );
            });

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: [state],
              now: now,
            );

            final filtered = result[state.id]!;

            // Verify: all returned activities have stateEnteredAt >= threshold
            for (final activity in filtered) {
              expect(
                activity.stateEnteredAt.isBefore(threshold),
                isFalse,
                reason:
                    'Iteration $i: Activity "${activity.id}" with stateEnteredAt '
                    '${activity.stateEnteredAt} should not appear — threshold is $threshold '
                    '(${thresholdDays} days back from $now)',
              );
            }

            // Verify: all activities NOT returned are older than threshold
            final filteredIds = filtered.map((a) => a.id).toSet();
            for (final activity in activities) {
              if (!filteredIds.contains(activity.id)) {
                expect(
                  activity.stateEnteredAt.isBefore(threshold),
                  isTrue,
                  reason:
                      'Iteration $i: Activity "${activity.id}" with stateEnteredAt '
                      '${activity.stateEnteredAt} was excluded but is within threshold $threshold',
                );
              }
            }
          }
        },
      );

      test(
        'states without productionThresholdDays retain all activities (no filtering)',
        () {
          for (var i = 0; i < 100; i++) {
            final now = DateTime.utc(2025, 6, 15);
            final sortOrder =
                random.nextBool() ? SortOrder.oldestFirst : SortOrder.newestFirst;
            final state = KanbanState(
              id: 'state_no_threshold',
              name: 'NoThreshold',
              order: 0,
              sortOrder: sortOrder,
              isDefault: false,
              productionThresholdDays: null,
            );

            // Generate activities with very old stateEnteredAt values
            final activityCount = random.nextInt(15) + 3;
            final activities = List.generate(activityCount, (j) {
              return Activity(
                id: 'activity_$j',
                title: 'Activity $j',
                currentStateId: state.id,
                sectorId: 'sector_1',
                createdAt: _randomDateTime(now, 500),
                createdBy: 'user_1',
                lastModifiedAt: _randomDateTime(now, 60),
                lastModifiedBy: 'user_1',
                stateEnteredAt: _randomDateTime(now, 500), // very old
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              );
            });

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: [state],
              now: now,
            );

            // All activities should be retained (no filtering)
            expect(
              result[state.id]!.length,
              equals(activityCount),
              reason:
                  'Iteration $i: All $activityCount activities should be retained '
                  'when no productionThresholdDays is set',
            );
          }
        },
      );

      test(
        'sorting is applied correctly even after threshold filtering',
        () {
          for (var i = 0; i < 100; i++) {
            final now = DateTime.utc(2025, 6, 15);
            final thresholdDays = random.nextInt(30) + 5;
            final sortOrder =
                random.nextBool() ? SortOrder.oldestFirst : SortOrder.newestFirst;

            final state = KanbanState(
              id: 'state_filtered_sorted',
              name: 'FilteredSorted',
              order: 0,
              sortOrder: sortOrder,
              isDefault: false,
              productionThresholdDays: thresholdDays,
            );

            final threshold = now.subtract(Duration(days: thresholdDays));

            // Generate activities all within threshold to ensure they all pass filtering
            final activityCount = random.nextInt(15) + 3;
            final activities = List.generate(activityCount, (j) {
              // Within threshold (0 to thresholdDays-1 days back)
              final offsetSeconds =
                  random.nextInt((thresholdDays - 1) * 24 * 60 * 60);
              final stateEnteredAt =
                  now.subtract(Duration(seconds: offsetSeconds));

              return Activity(
                id: 'activity_$j',
                title: 'Activity $j',
                currentStateId: state.id,
                sectorId: 'sector_1',
                createdAt: _randomDateTime(now, 120),
                createdBy: 'user_1',
                lastModifiedAt: _randomDateTime(now, 60),
                lastModifiedBy: 'user_1',
                stateEnteredAt: stateEnteredAt,
                responsibleUsers: const ['user_1'],
                isConflicted: false,
                version: 1,
              );
            });

            final result = groupActivitiesByState.execute(
              activities: activities,
              states: [state],
              now: now,
            );

            final sorted = result[state.id]!;

            // All activities should pass the filter (they're within threshold)
            expect(sorted.length, equals(activityCount));

            // Verify sort order
            for (var j = 0; j < sorted.length - 1; j++) {
              if (sortOrder == SortOrder.oldestFirst) {
                expect(
                  sorted[j].stateEnteredAt.compareTo(sorted[j + 1].stateEnteredAt) <= 0,
                  isTrue,
                  reason:
                      'Iteration $i: oldestFirst sort violated at index $j',
                );
              } else {
                expect(
                  sorted[j].stateEnteredAt.compareTo(sorted[j + 1].stateEnteredAt) >= 0,
                  isTrue,
                  reason:
                      'Iteration $i: newestFirst sort violated at index $j',
                );
              }
            }
          }
        },
      );
    },
  );
}
