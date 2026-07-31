import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';
import 'package:activity_tracker/domain/repositories/conflict_repository.dart';
import 'package:activity_tracker/domain/use_cases/cast_vote_use_case.dart';

/// Feature: activity-tracker
/// Property 23: Each user may cast exactly one vote per conflict
///
/// **Validates: Requirements 13.6**
///
/// For any conflict and any user who has already cast a vote, a second vote
/// attempt SHALL be rejected and the existing vote SHALL remain unchanged.

class MockConflictRepository extends Mock implements ConflictRepository {}

void main() {
  late MockConflictRepository mockConflictRepository;
  final random = Random(42); // Fixed seed for reproducibility

  setUp(() {
    mockConflictRepository = MockConflictRepository();
    when(() => mockConflictRepository.castVote(any(), any()))
        .thenAnswer((_) async {});
  });

  // --- Generators ---

  /// Generates a random alphanumeric string of the given [length].
  String _randomId(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a random ConflictVersion.
  ConflictVersion _generateVersion() {
    return ConflictVersion(
      versionId: _randomId(10),
      value: _randomId(20),
      authorId: _randomId(8),
      modifiedAt: DateTime.utc(
        2024,
        random.nextInt(12) + 1,
        random.nextInt(28) + 1,
        random.nextInt(24),
        random.nextInt(60),
      ),
    );
  }

  /// Generates a conflict with pre-existing votes from random users.
  /// Returns the conflict and a list of user IDs who have already voted.
  ({Conflict conflict, List<String> votedUserIds}) _generateConflictWithVotes() {
    // Generate 2-5 versions
    final versionCount = random.nextInt(4) + 2;
    final versions =
        List.generate(versionCount, (_) => _generateVersion());

    // Generate 1-10 pre-existing votes
    final voteCount = random.nextInt(10) + 1;
    final votedUserIds = <String>[];
    final votes = <String, String>{};

    for (var i = 0; i < voteCount; i++) {
      final userId = 'user_${_randomId(6)}';
      final versionId = versions[random.nextInt(versions.length)].versionId;
      votes[userId] = versionId;
      votedUserIds.add(userId);
    }

    // Voting deadline in the future so the vote isn't rejected for that reason
    final conflict = Conflict(
      id: 'conflict_${_randomId(8)}',
      activityId: 'activity_${_randomId(8)}',
      fieldPath: 'title',
      status: ConflictStatus.pending,
      createdAt: DateTime.utc(2024, 1, 1),
      votingDeadline: DateTime.utc(2099, 12, 31),
      versions: versions,
      votes: votes,
    );

    return (conflict: conflict, votedUserIds: votedUserIds);
  }

  group(
    'Feature: activity-tracker, Property 23: Each user may cast exactly one vote per conflict',
    () {
      test(
        'a user who has already voted is rejected with alreadyVoted error and existing vote remains unchanged',
        () async {
          for (var i = 0; i < 150; i++) {
            // Generate a conflict with pre-existing votes
            final generated = _generateConflictWithVotes();
            final conflict = generated.conflict;
            final votedUserIds = generated.votedUserIds;

            // Pick a random user who already voted
            final existingUserId =
                votedUserIds[random.nextInt(votedUserIds.length)];
            final existingVote = conflict.votes[existingUserId]!;

            // Choose a different version for the second vote attempt
            final otherVersions = conflict.versions
                .where((v) => v.versionId != existingVote)
                .toList();
            final newVersionId = otherVersions.isNotEmpty
                ? otherVersions[random.nextInt(otherVersions.length)].versionId
                : conflict.versions.first.versionId;

            // Create the use case with a fixed "now" that is before the deadline
            final useCase = CastVoteUseCase(
              conflictRepository: mockConflictRepository,
              now: () => DateTime.utc(2024, 6, 15),
            );

            // Attempt a second vote
            final result = await useCase.execute(
              conflict: conflict,
              userId: existingUserId,
              versionId: newVersionId,
            );

            // Verify rejection
            expect(
              result,
              isA<CastVoteFailure>(),
              reason:
                  'Expected CastVoteFailure for duplicate vote (iteration $i): '
                  'user=$existingUserId already voted for $existingVote, '
                  'attempted to vote for $newVersionId',
            );

            final failure = result as CastVoteFailure;
            expect(
              failure.error,
              equals(ActivityTrackerError.alreadyVoted),
              reason:
                  'Expected alreadyVoted error (iteration $i)',
            );

            // Verify the existing vote was not changed in the conflict object
            expect(
              conflict.votes[existingUserId],
              equals(existingVote),
              reason:
                  'Expected existing vote to remain unchanged (iteration $i): '
                  'user=$existingUserId should still have vote=$existingVote',
            );

            // Verify the repository was NOT called (vote should be rejected before persistence)
            verifyNever(
              () => mockConflictRepository.castVote(conflict.id, newVersionId),
            );
          }
        },
      );

      test(
        'the repository is never invoked when a duplicate vote is attempted',
        () async {
          for (var i = 0; i < 100; i++) {
            final generated = _generateConflictWithVotes();
            final conflict = generated.conflict;
            final votedUserIds = generated.votedUserIds;

            final existingUserId =
                votedUserIds[random.nextInt(votedUserIds.length)];

            // Try voting for any version (even the same one)
            final anyVersionId =
                conflict.versions[random.nextInt(conflict.versions.length)]
                    .versionId;

            final useCase = CastVoteUseCase(
              conflictRepository: mockConflictRepository,
              now: () => DateTime.utc(2024, 6, 15),
            );

            await useCase.execute(
              conflict: conflict,
              userId: existingUserId,
              versionId: anyVersionId,
            );

            // The repository castVote should never be called for duplicate votes
            verifyNever(
              () => mockConflictRepository.castVote(conflict.id, anyVersionId),
            );
          }
        },
      );
    },
  );
}
