import 'package:equatable/equatable.dart';

import '../../../domain/entities/conflict.dart';

/// Events that can be dispatched to the [ConflictBloc].
abstract class ConflictEvent extends Equatable {
  const ConflictEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered to start watching active conflicts for a specific user.
class LoadConflicts extends ConflictEvent {
  final String userId;

  const LoadConflicts({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Triggered when a user casts a vote on a conflict version.
class CastVote extends ConflictEvent {
  final Conflict conflict;
  final String userId;
  final String versionId;

  const CastVote({
    required this.conflict,
    required this.userId,
    required this.versionId,
  });

  @override
  List<Object?> get props => [conflict, userId, versionId];
}

/// Triggered to dismiss a resolved conflict from the list.
class DismissResolved extends ConflictEvent {
  final String conflictId;

  const DismissResolved({required this.conflictId});

  @override
  List<Object?> get props => [conflictId];
}
