import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/use_cases/calculate_duration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CalculateDuration calculateDuration;

  setUp(() {
    calculateDuration = CalculateDuration();
  });

  group('calculateDuration', () {
    test('returns 0 for timestamps less than 60 seconds apart', () {
      final entry = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final exit = DateTime.utc(2024, 1, 1, 10, 0, 59);
      expect(calculateDuration.calculateDuration(entry, exit), equals(0));
    });

    test('returns 1 for exactly 60 seconds', () {
      final entry = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final exit = DateTime.utc(2024, 1, 1, 10, 1, 0);
      expect(calculateDuration.calculateDuration(entry, exit), equals(1));
    });

    test('floors partial minutes down', () {
      final entry = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final exit = DateTime.utc(2024, 1, 1, 10, 2, 30);
      expect(calculateDuration.calculateDuration(entry, exit), equals(2));
    });

    test('handles multi-hour differences', () {
      final entry = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final exit = DateTime.utc(2024, 1, 1, 12, 30, 0);
      expect(calculateDuration.calculateDuration(entry, exit), equals(150));
    });

    test('handles multi-day differences', () {
      final entry = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final exit = DateTime.utc(2024, 1, 3, 0, 0, 0);
      expect(calculateDuration.calculateDuration(entry, exit), equals(2880));
    });

    test('returns 0 when entry equals exit', () {
      final timestamp = DateTime.utc(2024, 1, 1, 10, 0, 0);
      expect(calculateDuration.calculateDuration(timestamp, timestamp), equals(0));
    });
  });

  group('aggregateTimePerState', () {
    test('returns empty map for empty entries list', () {
      expect(calculateDuration.aggregateTimePerState([]), equals({}));
    });

    test('aggregates single entry correctly', () {
      final entries = [
        TimelineEntry(
          id: '1',
          fromStateId: 'backlog',
          toStateId: 'development',
          transitionedAt: DateTime.utc(2024, 1, 1, 12, 0, 0),
          transitionedBy: 'user1',
          durationMinutes: 120,
        ),
      ];
      final result = calculateDuration.aggregateTimePerState(entries);
      expect(result, equals({'backlog': 120}));
    });

    test('sums durations for same fromStateId', () {
      final entries = [
        TimelineEntry(
          id: '1',
          fromStateId: 'backlog',
          toStateId: 'development',
          transitionedAt: DateTime.utc(2024, 1, 1, 12, 0, 0),
          transitionedBy: 'user1',
          durationMinutes: 60,
        ),
        TimelineEntry(
          id: '2',
          fromStateId: 'development',
          toStateId: 'backlog',
          transitionedAt: DateTime.utc(2024, 1, 2, 12, 0, 0),
          transitionedBy: 'user1',
          durationMinutes: 30,
        ),
        TimelineEntry(
          id: '3',
          fromStateId: 'backlog',
          toStateId: 'production',
          transitionedAt: DateTime.utc(2024, 1, 3, 12, 0, 0),
          transitionedBy: 'user1',
          durationMinutes: 90,
        ),
      ];
      final result = calculateDuration.aggregateTimePerState(entries);
      expect(result, equals({'backlog': 150, 'development': 30}));
    });

    test('handles multiple states with multiple entries each', () {
      final entries = [
        TimelineEntry(
          id: '1',
          fromStateId: 'a',
          toStateId: 'b',
          transitionedAt: DateTime.utc(2024, 1, 1),
          transitionedBy: 'user1',
          durationMinutes: 10,
        ),
        TimelineEntry(
          id: '2',
          fromStateId: 'b',
          toStateId: 'c',
          transitionedAt: DateTime.utc(2024, 1, 2),
          transitionedBy: 'user1',
          durationMinutes: 20,
        ),
        TimelineEntry(
          id: '3',
          fromStateId: 'c',
          toStateId: 'a',
          transitionedAt: DateTime.utc(2024, 1, 3),
          transitionedBy: 'user1',
          durationMinutes: 15,
        ),
        TimelineEntry(
          id: '4',
          fromStateId: 'a',
          toStateId: 'b',
          transitionedAt: DateTime.utc(2024, 1, 4),
          transitionedBy: 'user1',
          durationMinutes: 5,
        ),
      ];
      final result = calculateDuration.aggregateTimePerState(entries);
      expect(result, equals({'a': 15, 'b': 20, 'c': 15}));
    });
  });

  group('calculateCurrentStateElapsed', () {
    test('returns 0 for less than 60 seconds elapsed', () {
      final stateEnteredAt = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final now = DateTime.utc(2024, 1, 1, 10, 0, 45);
      expect(
        calculateDuration.calculateCurrentStateElapsed(stateEnteredAt, now),
        equals(0),
      );
    });

    test('returns correct minutes for elapsed time', () {
      final stateEnteredAt = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final now = DateTime.utc(2024, 1, 1, 10, 5, 30);
      expect(
        calculateDuration.calculateCurrentStateElapsed(stateEnteredAt, now),
        equals(5),
      );
    });

    test('floors partial minutes', () {
      final stateEnteredAt = DateTime.utc(2024, 1, 1, 10, 0, 0);
      final now = DateTime.utc(2024, 1, 1, 10, 3, 59);
      expect(
        calculateDuration.calculateCurrentStateElapsed(stateEnteredAt, now),
        equals(3),
      );
    });

    test('handles large elapsed time', () {
      final stateEnteredAt = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final now = DateTime.utc(2024, 1, 8, 0, 0, 0);
      expect(
        calculateDuration.calculateCurrentStateElapsed(stateEnteredAt, now),
        equals(10080), // 7 days * 24 hours * 60 minutes
      );
    });
  });
}
