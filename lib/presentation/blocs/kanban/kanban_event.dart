import 'package:equatable/equatable.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/kanban_state.dart';

/// Base class for all Kanban board events.
sealed class KanbanEvent extends Equatable {
  const KanbanEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the Kanban board for a given sector.
class LoadBoard extends KanbanEvent {
  final String sectorId;

  const LoadBoard({required this.sectorId});

  @override
  List<Object?> get props => [sectorId];
}

/// Moves an activity to a different state column.
class MoveActivity extends KanbanEvent {
  final String activityId;
  final String targetStateId;
  final String movedBy;

  const MoveActivity({
    required this.activityId,
    required this.targetStateId,
    required this.movedBy,
  });

  @override
  List<Object?> get props => [activityId, targetStateId, movedBy];
}

/// Changes the sector filter on the Kanban board.
class ChangeFilter extends KanbanEvent {
  final String sectorId;

  const ChangeFilter({required this.sectorId});

  @override
  List<Object?> get props => [sectorId];
}

/// Refreshes the board by re-subscribing to streams.
class RefreshBoard extends KanbanEvent {
  const RefreshBoard();
}

/// Internal event emitted when the activity stream emits new data.
class ActivitiesUpdated extends KanbanEvent {
  final List<Activity> activities;

  const ActivitiesUpdated(this.activities);

  @override
  List<Object?> get props => [activities];
}

/// Internal event emitted when the states stream emits new data.
class StatesUpdated extends KanbanEvent {
  final List<KanbanState> states;

  const StatesUpdated(this.states);

  @override
  List<Object?> get props => [states];
}
