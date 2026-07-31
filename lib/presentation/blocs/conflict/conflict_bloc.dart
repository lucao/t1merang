import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/conflict.dart';
import '../../../domain/entities/conflict_status.dart';
import '../../../domain/repositories/conflict_repository.dart';
import '../../../domain/use_cases/cast_vote_use_case.dart';
import 'conflict_event.dart';
import 'conflict_state.dart';

/// BLoC that manages conflict resolution state.
///
/// Watches active conflicts for a given user via a real-time stream
/// and handles voting and dismissal of resolved conflicts.
///
/// Requirements: 13.5, 13.6
class ConflictBloc extends Bloc<ConflictEvent, ConflictState> {
  final ConflictRepository _conflictRepository;
  final CastVoteUseCase _castVoteUseCase;

  StreamSubscription<List<Conflict>>? _conflictsSubscription;

  ConflictBloc({
    required ConflictRepository conflictRepository,
    required CastVoteUseCase castVoteUseCase,
  })  : _conflictRepository = conflictRepository,
        _castVoteUseCase = castVoteUseCase,
        super(const ConflictIdle()) {
    on<LoadConflicts>(_onLoadConflicts);
    on<CastVote>(_onCastVote);
    on<DismissResolved>(_onDismissResolved);
    on<_ConflictsUpdated>(_onConflictsUpdated);
    on<_ConflictsError>(_onConflictsError);
  }

  void _onLoadConflicts(
    LoadConflicts event,
    Emitter<ConflictState> emit,
  ) {
    emit(const ConflictLoading());

    _conflictsSubscription?.cancel();
    _conflictsSubscription = _conflictRepository
        .watchActiveConflicts(event.userId)
        .listen(
          (conflicts) => add(_ConflictsUpdated(conflicts: conflicts)),
          onError: (Object error) =>
              add(_ConflictsError(message: error.toString())),
        );
  }

  void _onConflictsUpdated(
    _ConflictsUpdated event,
    Emitter<ConflictState> emit,
  ) {
    emit(ConflictLoaded(conflicts: event.conflicts));
  }

  void _onConflictsError(
    _ConflictsError event,
    Emitter<ConflictState> emit,
  ) {
    emit(ConflictError(message: event.message));
  }

  Future<void> _onCastVote(
    CastVote event,
    Emitter<ConflictState> emit,
  ) async {
    final result = await _castVoteUseCase.execute(
      conflict: event.conflict,
      userId: event.userId,
      versionId: event.versionId,
    );

    switch (result) {
      case CastVoteSuccess():
        // Vote was cast successfully; the stream will provide updated data.
        break;
      case CastVoteFailure(:final error):
        emit(ConflictError(message: error.name));
        break;
    }
  }

  void _onDismissResolved(
    DismissResolved event,
    Emitter<ConflictState> emit,
  ) {
    final currentState = state;
    if (currentState is ConflictLoaded) {
      final updatedConflicts = currentState.conflicts
          .where((c) => c.id != event.conflictId || c.status != ConflictStatus.resolved)
          .toList();
      emit(ConflictLoaded(conflicts: updatedConflicts));
    }
  }

  @override
  Future<void> close() {
    _conflictsSubscription?.cancel();
    return super.close();
  }
}

/// Internal event emitted when the conflicts stream pushes new data.
class _ConflictsUpdated extends ConflictEvent {
  final List<Conflict> conflicts;

  const _ConflictsUpdated({required this.conflicts});

  @override
  List<Object?> get props => [conflicts];
}

/// Internal event emitted when the conflicts stream encounters an error.
class _ConflictsError extends ConflictEvent {
  final String message;

  const _ConflictsError({required this.message});

  @override
  List<Object?> get props => [message];
}
