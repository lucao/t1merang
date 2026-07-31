import 'package:equatable/equatable.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/kanban_state.dart' as domain;

/// Base class for all Kanban board states.
sealed class KanbanBoardState extends Equatable {
  const KanbanBoardState();

  @override
  List<Object?> get props => [];
}

/// The board is loading data.
class KanbanLoading extends KanbanBoardState {
  const KanbanLoading();
}

/// The board has loaded successfully with grouped activities.
class KanbanLoaded extends KanbanBoardState {
  /// Activities grouped by state ID.
  final Map<String, List<Activity>> groupedActivities;

  /// The ordered list of Kanban states (columns).
  final List<domain.KanbanState> states;

  /// The current sector filter applied to the board.
  final String currentSectorId;

  const KanbanLoaded({
    required this.groupedActivities,
    required this.states,
    required this.currentSectorId,
  });

  @override
  List<Object?> get props => [groupedActivities, states, currentSectorId];
}

/// The board encountered an error.
class KanbanError extends KanbanBoardState {
  final String message;

  const KanbanError({required this.message});

  @override
  List<Object?> get props => [message];
}
