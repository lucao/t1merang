import '../entities/activity_tracker_error.dart';
import '../entities/conflict.dart';
import '../repositories/conflict_repository.dart';

/// Result of a cast vote operation.
sealed class CastVoteResult {
  const CastVoteResult();
}

class CastVoteSuccess extends CastVoteResult {
  const CastVoteSuccess();
}

class CastVoteFailure extends CastVoteResult {
  final ActivityTrackerError error;
  const CastVoteFailure(this.error);
}

/// Use case for casting a vote on a conflict.
///
/// Business rules:
/// - Each user may cast exactly one vote per conflict.
/// - If the user has already voted, the vote is rejected with [ActivityTrackerError.alreadyVoted].
/// - If the voting window has closed (votingDeadline has passed), the vote is rejected
///   with [ActivityTrackerError.votingWindowClosed].
/// - Otherwise, the vote is persisted via the [ConflictRepository].
///
/// Requirements: 13.6
class CastVoteUseCase {
  final ConflictRepository _conflictRepository;
  final DateTime Function() _now;

  CastVoteUseCase({
    required ConflictRepository conflictRepository,
    DateTime Function()? now,
  })  : _conflictRepository = conflictRepository,
        _now = now ?? DateTime.now;

  /// Executes the vote cast for [userId] on the given [conflict],
  /// choosing [versionId] as their preferred version.
  Future<CastVoteResult> execute({
    required Conflict conflict,
    required String userId,
    required String versionId,
  }) async {
    // Check if the user has already voted on this conflict.
    if (conflict.votes.containsKey(userId)) {
      return const CastVoteFailure(ActivityTrackerError.alreadyVoted);
    }

    // Check if the voting window is still open.
    final now = _now();
    if (now.isAfter(conflict.votingDeadline)) {
      return const CastVoteFailure(ActivityTrackerError.votingWindowClosed);
    }

    // Cast the vote via the repository.
    await _conflictRepository.castVote(conflict.id, versionId);

    return const CastVoteSuccess();
  }
}
