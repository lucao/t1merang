import '../entities/conflict.dart';

/// Abstract repository for managing conflicts and their resolution.
abstract class ConflictRepository {
  /// Watches active (pending) conflicts relevant to a specific user.
  Stream<List<Conflict>> watchActiveConflicts(String userId);

  /// Casts a vote for a specific version in a conflict.
  Future<void> castVote(String conflictId, String versionId);
}
