import '../entities/conflict.dart';
import '../entities/conflict_version.dart';

/// The method used to resolve a conflict.
enum ResolutionMethod {
  /// Resolved by majority vote (consensus).
  consensus,

  /// Resolved by most recent timestamp (fallback when no votes cast).
  fallback,
}

/// Result of resolving a conflict.
class ConflictResolutionResult {
  /// The versionId of the winning version.
  final String winningVersionId;

  /// The method used to determine the winner.
  final ResolutionMethod method;

  const ConflictResolutionResult({
    required this.winningVersionId,
    required this.method,
  });
}

/// Use case for resolving a conflict by applying the democratic resolution rules.
///
/// Resolution rules:
/// 1. If votes have been cast, the version with the most votes wins (consensus).
/// 2. If no votes have been cast, the version with the most recent modifiedAt
///    timestamp wins (fallback).
/// 3. If two or more versions are tied in votes, the tied version with the
///    most recent modifiedAt timestamp wins (still reported as consensus).
///
/// This use case operates on a [Conflict] entity directly — it is pure domain
/// logic with no infrastructure dependencies.
///
/// Requirements: 13.7, 13.8, 13.9
class ResolveConflictUseCase {
  const ResolveConflictUseCase();

  /// Resolves the given [conflict] and returns the winning version and method.
  ///
  /// The [conflict] must have at least one version in its [Conflict.versions]
  /// list. If the versions list is empty, an [ArgumentError] is thrown.
  ConflictResolutionResult execute(Conflict conflict) {
    final versions = conflict.versions;
    if (versions.isEmpty) {
      throw ArgumentError('Conflict must have at least one version');
    }

    final votes = conflict.votes;

    // If no votes have been cast, apply fallback: most recent timestamp.
    if (votes.isEmpty) {
      final winner = _mostRecentVersion(versions);
      return ConflictResolutionResult(
        winningVersionId: winner.versionId,
        method: ResolutionMethod.fallback,
      );
    }

    // Count votes per version.
    final voteCounts = <String, int>{};
    for (final versionId in votes.values) {
      voteCounts[versionId] = (voteCounts[versionId] ?? 0) + 1;
    }

    // Find the maximum vote count.
    final maxVotes = voteCounts.values.reduce((a, b) => a > b ? a : b);

    // Collect all versions tied at the maximum vote count.
    final tiedVersionIds = voteCounts.entries
        .where((entry) => entry.value == maxVotes)
        .map((entry) => entry.key)
        .toSet();

    // If only one version has the max votes, it wins.
    // If multiple versions are tied, break tie by most recent modifiedAt.
    final tiedVersions = versions
        .where((v) => tiedVersionIds.contains(v.versionId))
        .toList();

    final winner = _mostRecentVersion(tiedVersions);
    return ConflictResolutionResult(
      winningVersionId: winner.versionId,
      method: ResolutionMethod.consensus,
    );
  }

  /// Returns the version with the most recent [ConflictVersion.modifiedAt].
  ConflictVersion _mostRecentVersion(List<ConflictVersion> versions) {
    return versions.reduce(
      (a, b) => b.modifiedAt.isAfter(a.modifiedAt) ? b : a,
    );
  }
}
