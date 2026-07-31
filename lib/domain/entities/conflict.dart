import 'package:equatable/equatable.dart';

import 'conflict_status.dart';
import 'conflict_version.dart';

/// A state in which two or more concurrent modifications to the same
/// data item are detected during synchronization.
class Conflict extends Equatable {
  final String id;
  final String activityId;
  final String fieldPath;
  final ConflictStatus status;
  final DateTime createdAt;
  final DateTime votingDeadline;
  final List<ConflictVersion> versions;

  /// Maps userId to the versionId they voted for.
  final Map<String, String> votes;

  const Conflict({
    required this.id,
    required this.activityId,
    required this.fieldPath,
    required this.status,
    required this.createdAt,
    required this.votingDeadline,
    required this.versions,
    required this.votes,
  });

  @override
  List<Object?> get props => [
        id,
        activityId,
        fieldPath,
        status,
        createdAt,
        votingDeadline,
        versions,
        votes,
      ];
}
