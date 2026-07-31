import 'package:flutter_test/flutter_test.dart';
import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/kanban_state.dart';
import 'package:activity_tracker/domain/entities/sort_order.dart';
import 'package:activity_tracker/domain/use_cases/group_activities_by_state.dart';

void main() {
  late GroupActivitiesByState groupActivitiesByState;

  setUp(() {
    groupActivitiesByState = const GroupActivitiesByState();
  });

  Activity makeActivity({
    required String id,
    required String currentStateId,
    required DateTime stateEnteredAt,
  }) {
    return Activity(
      id: id,
      title: 'Activity $id',
      currentStateId: currentStateId,
      sectorId: 'sector-1',
      createdAt: DateTime.utc(2024, 1, 1),
      createdBy: 'user-1',
      lastModifiedAt: DateTime.utc(2024, 1, 1),
      lastModifiedBy: 'user-1',
      stateEnteredAt: stateEnteredAt,
      responsibleUsers: const ['user-1'],
      isConflicted: false,
      version: 1,
    );
  }

  final backlogState = const KanbanState(
    id: 'backlog',
    name: 'Backlog',
    order: 0,
    sortOrder: SortOrder.oldestFirst,
    isDefault: true,
  );

  final devState = const KanbanState(
    id: 'development',
    name: 'Development',
    order: 1,
    sortOrder: SortOrder.newestFirst,
    isDefault: true,
  );

  final prodState = const KanbanState(
    id: 'production',
    name: 'Production',
    order: 2,
    sortOrder: SortOrder.newestFirst,
    isDefault: true,
    productionThresholdDays: 30,
  );

  group('GroupActivitiesByState', () {
    test('groups activities by their currentStateId', () {
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
        makeActivity(
          id: '2',
          currentStateId: 'development',
          stateEnteredAt: DateTime.utc(2024, 3, 2),
        ),
        makeActivity(
          id: '3',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 3),
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [backlogState, devState, prodState],
      );

      expect(result['backlog']!.length, 2);
      expect(result['development']!.length, 1);
      expect(result['production']!.length, 0);
    });

    test('returns empty lists for states with no activities', () {
      final result = groupActivitiesByState.execute(
        activities: [],
        states: [backlogState, devState, prodState],
      );

      expect(result['backlog'], isEmpty);
      expect(result['development'], isEmpty);
      expect(result['production'], isEmpty);
    });

    test('sorts by oldest first for Backlog state', () {
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 15),
        ),
        makeActivity(
          id: '2',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
        makeActivity(
          id: '3',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 10),
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [backlogState],
      );

      final ids = result['backlog']!.map((a) => a.id).toList();
      expect(ids, ['2', '3', '1']);
    });

    test('sorts by newest first for Development state', () {
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'development',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
        makeActivity(
          id: '2',
          currentStateId: 'development',
          stateEnteredAt: DateTime.utc(2024, 3, 15),
        ),
        makeActivity(
          id: '3',
          currentStateId: 'development',
          stateEnteredAt: DateTime.utc(2024, 3, 10),
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [devState],
      );

      final ids = result['development']!.map((a) => a.id).toList();
      expect(ids, ['2', '3', '1']);
    });

    test('filters out activities older than threshold in Production state', () {
      final now = DateTime.utc(2024, 4, 1);
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 20), // 12 days ago — within threshold
        ),
        makeActivity(
          id: '2',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 2, 1), // 59 days ago — older than 30 days
        ),
        makeActivity(
          id: '3',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 2), // 30 days ago — exactly at threshold boundary
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [prodState],
        now: now,
      );

      // Activity '2' is older than 30 days, should be filtered out
      // Activity '3' entered exactly 30 days ago, threshold checks isBefore so it stays
      final ids = result['production']!.map((a) => a.id).toList();
      expect(ids, contains('1'));
      expect(ids, isNot(contains('2')));
      expect(ids, contains('3'));
    });

    test('activities with unknown stateId are excluded', () {
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'unknown-state',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
        makeActivity(
          id: '2',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [backlogState],
      );

      expect(result['backlog']!.length, 1);
      expect(result['backlog']!.first.id, '2');
      expect(result.containsKey('unknown-state'), isFalse);
    });

    test('each activity appears exactly once in the result', () {
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'backlog',
          stateEnteredAt: DateTime.utc(2024, 3, 1),
        ),
        makeActivity(
          id: '2',
          currentStateId: 'development',
          stateEnteredAt: DateTime.utc(2024, 3, 2),
        ),
        makeActivity(
          id: '3',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 28),
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [backlogState, devState, prodState],
        now: DateTime.utc(2024, 4, 1),
      );

      final allActivities = result.values.expand((list) => list).toList();
      final allIds = allActivities.map((a) => a.id).toSet();
      expect(allIds.length, allActivities.length); // No duplicates
    });

    test('Production threshold filtering combined with newestFirst sorting', () {
      final now = DateTime.utc(2024, 4, 1);
      final activities = [
        makeActivity(
          id: '1',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 5), // 27 days ago
        ),
        makeActivity(
          id: '2',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 25), // 7 days ago
        ),
        makeActivity(
          id: '3',
          currentStateId: 'production',
          stateEnteredAt: DateTime.utc(2024, 3, 15), // 17 days ago
        ),
      ];

      final result = groupActivitiesByState.execute(
        activities: activities,
        states: [prodState],
        now: now,
      );

      // All within 30 days, sorted newest first
      final ids = result['production']!.map((a) => a.id).toList();
      expect(ids, ['2', '3', '1']);
    });
  });
}
