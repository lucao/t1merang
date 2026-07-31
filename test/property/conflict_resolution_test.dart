import 'dart:math';

import 'package:test/test.dart';

import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';
import 'package:activity_tracker/domain/use_cases/resolve_conflict_use_case.dart';

/// Feature: activity-tracker
/// Property 24: Conflict resolution applies majority with timestamp fallback
///
/// **Validates: Requirements 13.7, 13.8, 13.9**
///
/// For any conflict with votes cast, resolution SHALL apply the version with
/// the highest vote count. If no votes are cast, resolution SHALL apply the
/// version with the most recent modification timestamp. If two or more versions
/// are tied in votes, resolution SHALL apply the tied version with the most
/// recent modification timestamp.

void main() {
  const useCase = ResolveConflictUseCase();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a unique version ID.
  String _generateVersionId(int index) => 'version_$index';

  /// Generates a random DateTime within a reasonable range.
  DateTime _generateTimestamp() {
    final base = DateTime(2024, 1, 1);
    final offsetSeconds = random.nextInt(365 * 24 * 60 * 60); // within a year
    return base.add(Duration(seconds: offsetSeconds));
  }

  /// Generates a list of ConflictVersions with unique IDs and random timestamps.
  /// [count] must be >= 2.
  List<ConflictVersion> _generateVersions(int count) {
    // Generate distinct timestamps to avoid ambiguity except when explicitly testing ties
    final timestamps = <DateTime>[];
    for (var i = 0; i < count; i++) {
      timestamps.add(_generateTimestamp());
    }

    return List.generate(count, (i) {
      return ConflictVersion(
        versionId: _generateVersionId(i),
        value: 'value_$i',
        authorId: 'author_$i',
        modifiedAt: timestamps[i],
      );
    });
  }

  /// Generates a Conflict with the given versions and votes.
  Conflict _generateConflict({
    required List<ConflictVersion> versions,
    required Map<String, String> votes,
  }) {
    return Conflict(
      id: 'conflict_${random.nextInt(10000)}',
      activityId: 'activity_${random.nextInt(10000)}',
      fieldPath: 'title',
      status: ConflictStatus.pending,
      createdAt: DateTime(2024, 1, 1),
      votingDeadline: DateTime(2024, 1, 2),
      versions: versions,
      votes: votes,
    );
  }

  /// Generates votes where one version has a clear majority (more votes than any other).
  Map<String, String> _generateClearMajorityVotes({
    required List<ConflictVersion> versions,
    required int winnerIndex,
  }) {
    final votes = <String, String>{};
    final winnerVersionId = versions[winnerIndex].versionId;

    // Give the winner the most votes
    final totalVoters = random.nextInt(8) + 3; // 3-10 voters
    final winnerVotes = (totalVoters ~/ 2) + 1 + random.nextInt(3); // majority

    // Assign winner votes
    for (var i = 0; i < winnerVotes && i < totalVoters; i++) {
      votes['voter_$i'] = winnerVersionId;
    }

    // Distribute remaining votes among other versions
    var voterIdx = winnerVotes;
    for (var v = 0; v < versions.length && voterIdx < totalVoters; v++) {
      if (v == winnerIndex) continue;
      // Give at most (winnerVotes - 1) to any other version to keep majority clear
      final otherVotes = random.nextInt(winnerVotes.clamp(1, winnerVotes - 1).toInt());
      for (var j = 0; j < otherVotes && voterIdx < totalVoters; j++) {
        votes['voter_$voterIdx'] = versions[v].versionId;
        voterIdx++;
      }
    }

    return votes;
  }

  /// Generates votes where two or more versions are tied at the highest vote count.
  /// Returns the votes and the set of tied version indices.
  ({Map<String, String> votes, Set<int> tiedIndices}) _generateTiedVotes({
    required List<ConflictVersion> versions,
  }) {
    final tiedCount = random.nextInt(versions.length - 1) + 2; // 2 to versions.length
    final tiedIndices = <int>{};
    while (tiedIndices.length < tiedCount) {
      tiedIndices.add(random.nextInt(versions.length));
    }

    final votesPerTied = random.nextInt(3) + 1; // 1-3 votes each
    final votes = <String, String>{};
    var voterIdx = 0;

    for (final idx in tiedIndices) {
      for (var j = 0; j < votesPerTied; j++) {
        votes['voter_$voterIdx'] = versions[idx].versionId;
        voterIdx++;
      }
    }

    // Give remaining versions fewer votes (0 to votesPerTied - 1)
    for (var v = 0; v < versions.length; v++) {
      if (tiedIndices.contains(v)) continue;
      final fewerVotes = random.nextInt(votesPerTied); // 0 to votesPerTied-1
      for (var j = 0; j < fewerVotes; j++) {
        votes['voter_$voterIdx'] = versions[v].versionId;
        voterIdx++;
      }
    }

    return (votes: votes, tiedIndices: tiedIndices);
  }

  group(
    'Feature: activity-tracker, Property 24: Conflict resolution applies majority with timestamp fallback',
    () {
      test(
        'no votes: resolution applies the version with the most recent modification timestamp (fallback)',
        () {
          for (var i = 0; i < 150; i++) {
            final versionCount = random.nextInt(4) + 2; // 2-5 versions
            final versions = _generateVersions(versionCount);

            final conflict = _generateConflict(
              versions: versions,
              votes: {}, // No votes cast
            );

            final result = useCase.execute(conflict);

            // Find the version with the most recent timestamp
            final expectedWinner = versions.reduce(
              (a, b) => b.modifiedAt.isAfter(a.modifiedAt) ? b : a,
            );

            expect(
              result.winningVersionId,
              equals(expectedWinner.versionId),
              reason:
                  'With no votes (iteration $i), expected version with most recent '
                  'timestamp "${expectedWinner.versionId}" (${expectedWinner.modifiedAt}) '
                  'to win, but got "${result.winningVersionId}"',
            );

            expect(
              result.method,
              equals(ResolutionMethod.fallback),
              reason:
                  'With no votes (iteration $i), expected fallback method',
            );
          }
        },
      );

      test(
        'clear majority: resolution applies the version with the highest vote count (consensus)',
        () {
          for (var i = 0; i < 150; i++) {
            final versionCount = random.nextInt(4) + 2; // 2-5 versions
            final versions = _generateVersions(versionCount);
            final winnerIndex = random.nextInt(versionCount);

            final votes = _generateClearMajorityVotes(
              versions: versions,
              winnerIndex: winnerIndex,
            );

            final conflict = _generateConflict(
              versions: versions,
              votes: votes,
            );

            final result = useCase.execute(conflict);

            expect(
              result.winningVersionId,
              equals(versions[winnerIndex].versionId),
              reason:
                  'With clear majority (iteration $i), expected version '
                  '"${versions[winnerIndex].versionId}" to win',
            );

            expect(
              result.method,
              equals(ResolutionMethod.consensus),
              reason:
                  'With votes cast (iteration $i), expected consensus method',
            );
          }
        },
      );

      test(
        'tied votes: resolution applies the tied version with the most recent modification timestamp',
        () {
          for (var i = 0; i < 150; i++) {
            final versionCount = random.nextInt(4) + 2; // 2-5 versions

            // Generate versions with guaranteed distinct timestamps for tied versions
            final versions = <ConflictVersion>[];
            final baseTime = DateTime(2024, 1, 1);
            for (var v = 0; v < versionCount; v++) {
              // Ensure distinct timestamps by spacing them out
              final offsetSeconds = (v + 1) * 1000 + random.nextInt(500);
              versions.add(ConflictVersion(
                versionId: _generateVersionId(v),
                value: 'value_$v',
                authorId: 'author_$v',
                modifiedAt: baseTime.add(Duration(seconds: offsetSeconds)),
              ));
            }

            final tiedResult = _generateTiedVotes(versions: versions);
            final votes = tiedResult.votes;
            final tiedIndices = tiedResult.tiedIndices;

            final conflict = _generateConflict(
              versions: versions,
              votes: votes,
            );

            final result = useCase.execute(conflict);

            // Among tied versions, the one with the most recent timestamp should win
            final tiedVersions =
                tiedIndices.map((idx) => versions[idx]).toList();
            final expectedWinner = tiedVersions.reduce(
              (a, b) => b.modifiedAt.isAfter(a.modifiedAt) ? b : a,
            );

            expect(
              result.winningVersionId,
              equals(expectedWinner.versionId),
              reason:
                  'With tied votes (iteration $i), expected version with most recent '
                  'timestamp among tied versions "${expectedWinner.versionId}" '
                  '(${expectedWinner.modifiedAt}) to win, but got "${result.winningVersionId}". '
                  'Tied indices: $tiedIndices',
            );

            expect(
              result.method,
              equals(ResolutionMethod.consensus),
              reason:
                  'With votes cast (iteration $i), expected consensus method even in tie',
            );
          }
        },
      );

      test(
        'single voter: the voted version always wins regardless of timestamps',
        () {
          for (var i = 0; i < 100; i++) {
            final versionCount = random.nextInt(4) + 2; // 2-5 versions
            final versions = _generateVersions(versionCount);

            // Single vote for a random version (which may NOT have the latest timestamp)
            final votedIndex = random.nextInt(versionCount);
            final votes = {'single_voter': versions[votedIndex].versionId};

            final conflict = _generateConflict(
              versions: versions,
              votes: votes,
            );

            final result = useCase.execute(conflict);

            // With a single vote, that version has the most votes (1 vs 0 for others)
            // But all versions have 0 votes except the voted one (which has 1)
            // So the voted version should win by consensus
            expect(
              result.winningVersionId,
              equals(versions[votedIndex].versionId),
              reason:
                  'With single vote (iteration $i), expected voted version '
                  '"${versions[votedIndex].versionId}" to win',
            );

            expect(
              result.method,
              equals(ResolutionMethod.consensus),
              reason: 'With votes cast, expected consensus method',
            );
          }
        },
      );
    },
  );
}
