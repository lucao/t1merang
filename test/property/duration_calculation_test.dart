import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/use_cases/calculate_duration.dart';

/// Feature: activity-tracker
/// Property 12: Duration calculation with minute-level floor precision
///
/// **Validates: Requirements 5.1, 5.3**
///
/// For any two UTC timestamps (entry and exit) where exit > entry, the
/// calculated duration SHALL equal floor((exit - entry) / 60 seconds),
/// expressed in minutes.
///
/// Property 13: Cumulative time aggregation per state
///
/// **Validates: Requirements 5.2**
///
/// For any activity with a list of timeline entries, the cumulative time for
/// each state SHALL equal the sum of all durationMinutes values for entries
/// whose fromStateId matches that state.

void main() {
  final calculator = CalculateDuration();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random UTC DateTime within a reasonable range.
  DateTime generateRandomUtcTimestamp() {
    // Range: 2020-01-01 to 2030-01-01 (in seconds since epoch)
    const minEpochSeconds = 1577836800; // 2020-01-01T00:00:00Z
    const maxEpochSeconds = 1893456000; // 2030-01-01T00:00:00Z
    final epochSeconds =
        minEpochSeconds + random.nextInt(maxEpochSeconds - minEpochSeconds);
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    );
  }

  /// Generates a pair of UTC timestamps where exit > entry.
  /// Returns (entry, exit) with a positive difference.
  (DateTime, DateTime) generateTimestampPair() {
    final entry = generateRandomUtcTimestamp();
    // Add between 1 second and 30 days (in seconds)
    final offsetSeconds = random.nextInt(30 * 24 * 60 * 60) + 1;
    final exit = entry.add(Duration(seconds: offsetSeconds));
    return (entry, exit);
  }

  /// Generates a random state ID from a pool of possible states.
  String generateStateId() {
    const stateIds = [
      'backlog',
      'development',
      'production',
      'testing',
      'review',
      'done',
      'blocked',
      'in-progress',
    ];
    return stateIds[random.nextInt(stateIds.length)];
  }

  /// Generates a random timeline entry with a given or random fromStateId.
  TimelineEntry generateTimelineEntry({String? fromStateId}) {
    return TimelineEntry(
      id: 'entry-${random.nextInt(100000)}',
      fromStateId: fromStateId ?? generateStateId(),
      toStateId: generateStateId(),
      transitionedAt: generateRandomUtcTimestamp(),
      transitionedBy: 'user-${random.nextInt(100)}',
      durationMinutes: random.nextInt(10000), // 0 to ~7 days in minutes
    );
  }

  /// Generates a list of timeline entries with varying fromStateId values.
  List<TimelineEntry> generateTimelineEntries() {
    final count = random.nextInt(20) + 1; // 1 to 20 entries
    return List.generate(count, (_) => generateTimelineEntry());
  }

  group(
    'Feature: activity-tracker, Property 12: Duration calculation with minute-level floor precision',
    () {
      test(
        'for any two UTC timestamps where exit > entry, duration equals floor((exit - entry) / 60)',
        () {
          for (var i = 0; i < 150; i++) {
            final (entry, exit) = generateTimestampPair();
            final result = calculator.calculateDuration(entry, exit);

            final expectedSeconds = exit.difference(entry).inSeconds;
            final expectedMinutes = expectedSeconds ~/ 60;

            expect(
              result,
              equals(expectedMinutes),
              reason:
                  'Iteration $i: entry=$entry, exit=$exit, '
                  'diffSeconds=$expectedSeconds, expected=${expectedMinutes}min, got=${result}min',
            );
          }
        },
      );

      test(
        'duration is always non-negative when exit > entry',
        () {
          for (var i = 0; i < 150; i++) {
            final (entry, exit) = generateTimestampPair();
            final result = calculator.calculateDuration(entry, exit);

            expect(
              result,
              greaterThanOrEqualTo(0),
              reason:
                  'Iteration $i: duration should be non-negative for exit > entry',
            );
          }
        },
      );

      test(
        'partial minutes are always rounded down (floor)',
        () {
          for (var i = 0; i < 150; i++) {
            final entry = generateRandomUtcTimestamp();
            // Generate a difference that has a non-zero remainder when divided by 60
            final fullMinutes = random.nextInt(1000) + 1;
            final extraSeconds = random.nextInt(59) + 1; // 1-59 extra seconds
            final totalSeconds = fullMinutes * 60 + extraSeconds;
            final exit = entry.add(Duration(seconds: totalSeconds));

            final result = calculator.calculateDuration(entry, exit);

            expect(
              result,
              equals(fullMinutes),
              reason:
                  'Iteration $i: $totalSeconds seconds = $fullMinutes full minutes + $extraSeconds extra seconds, '
                  'floor should give $fullMinutes, got $result',
            );
          }
        },
      );

      test(
        'differences less than 60 seconds produce zero minutes',
        () {
          for (var i = 0; i < 100; i++) {
            final entry = generateRandomUtcTimestamp();
            final offsetSeconds = random.nextInt(59) + 1; // 1-59 seconds
            final exit = entry.add(Duration(seconds: offsetSeconds));

            final result = calculator.calculateDuration(entry, exit);

            expect(
              result,
              equals(0),
              reason:
                  'Iteration $i: $offsetSeconds seconds < 60 should produce 0 minutes, got $result',
            );
          }
        },
      );

      test(
        'currentStateElapsed uses same floor logic as calculateDuration',
        () {
          for (var i = 0; i < 150; i++) {
            final (stateEnteredAt, now) = generateTimestampPair();
            final elapsed =
                calculator.calculateCurrentStateElapsed(stateEnteredAt, now);
            final duration =
                calculator.calculateDuration(stateEnteredAt, now);

            expect(
              elapsed,
              equals(duration),
              reason:
                  'Iteration $i: calculateCurrentStateElapsed and calculateDuration '
                  'should produce the same result for the same timestamps',
            );
          }
        },
      );
    },
  );

  group(
    'Feature: activity-tracker, Property 13: Cumulative time aggregation per state',
    () {
      test(
        'cumulative time for each state equals sum of durationMinutes for entries with matching fromStateId',
        () {
          for (var i = 0; i < 150; i++) {
            final entries = generateTimelineEntries();
            final result = calculator.aggregateTimePerState(entries);

            // Compute expected aggregation manually
            final expected = <String, int>{};
            for (final entry in entries) {
              expected.update(
                entry.fromStateId,
                (current) => current + entry.durationMinutes,
                ifAbsent: () => entry.durationMinutes,
              );
            }

            expect(
              result,
              equals(expected),
              reason:
                  'Iteration $i: aggregated times should match manual sum per fromStateId. '
                  'Entries count=${entries.length}',
            );
          }
        },
      );

      test(
        'result contains exactly the set of unique fromStateId values present in entries',
        () {
          for (var i = 0; i < 150; i++) {
            final entries = generateTimelineEntries();
            final result = calculator.aggregateTimePerState(entries);

            final expectedKeys =
                entries.map((e) => e.fromStateId).toSet();

            expect(
              result.keys.toSet(),
              equals(expectedKeys),
              reason:
                  'Iteration $i: result keys should contain exactly the unique fromStateIds. '
                  'Expected: $expectedKeys, got: ${result.keys.toSet()}',
            );
          }
        },
      );

      test(
        'total aggregated minutes across all states equals sum of all entry durationMinutes',
        () {
          for (var i = 0; i < 150; i++) {
            final entries = generateTimelineEntries();
            final result = calculator.aggregateTimePerState(entries);

            final totalFromResult =
                result.values.fold<int>(0, (sum, v) => sum + v);
            final totalFromEntries =
                entries.fold<int>(0, (sum, e) => sum + e.durationMinutes);

            expect(
              totalFromResult,
              equals(totalFromEntries),
              reason:
                  'Iteration $i: total aggregated minutes ($totalFromResult) should equal '
                  'sum of all entry durations ($totalFromEntries)',
            );
          }
        },
      );

      test(
        'empty entry list produces empty aggregation map',
        () {
          for (var i = 0; i < 100; i++) {
            final result = calculator.aggregateTimePerState([]);

            expect(
              result,
              isEmpty,
              reason: 'Iteration $i: empty input should produce empty map',
            );
          }
        },
      );

      test(
        'entries with same fromStateId are correctly summed',
        () {
          for (var i = 0; i < 150; i++) {
            // Generate multiple entries all with the same fromStateId
            final stateId = generateStateId();
            final count = random.nextInt(10) + 2; // At least 2 entries
            final entries = List.generate(
              count,
              (_) => generateTimelineEntry(fromStateId: stateId),
            );

            final result = calculator.aggregateTimePerState(entries);

            final expectedSum =
                entries.fold<int>(0, (sum, e) => sum + e.durationMinutes);

            expect(
              result.length,
              equals(1),
              reason:
                  'Iteration $i: all entries have same fromStateId, result should have 1 key',
            );
            expect(
              result[stateId],
              equals(expectedSum),
              reason:
                  'Iteration $i: sum for "$stateId" should be $expectedSum, got ${result[stateId]}',
            );
          }
        },
      );
    },
  );
}
