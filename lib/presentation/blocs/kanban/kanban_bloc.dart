import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_tracker_error.dart';
import '../../../domain/entities/kanban_state.dart' as domain;
import '../../../domain/entities/permission.dart';
import '../../../domain/repositories/access_control_repository.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/repositories/state_repository.dart';
import '../../../domain/use_cases/group_activities_by_state.dart';
import '../../../domain/use_cases/move_activity_use_case.dart';
import 'kanban_event.dart';
import 'kanban_state.dart';

/// BLoC managing the Kanban board state.
///
/// Subscribes to real-time activity and state streams, applies grouping,
/// sorting, and threshold filtering, and checks permissions before actions.
class KanbanBloc extends Bloc<KanbanEvent, KanbanBoardState> {
  final ActivityRepository _activityRepository;
  final StateRepository _stateRepository;
  final AccessControlRepository _accessControlRepository;
  final MoveActivityUseCase _moveActivityUseCase;
  final GroupActivitiesByState _groupActivitiesByState;

  StreamSubscription<List<Activity>>? _activitiesSubscription;
  StreamSubscription<List<domain.KanbanState>>? _statesSubscription;

  /// Cached data for recomputing grouped activities when either stream updates.
  List<Activity> _currentActivities = [];
  List<domain.KanbanState> _currentStates = [];
  String _currentSectorId = '';

  KanbanBloc({
    required ActivityRepository activityRepository,
    required StateRepository stateRepository,
    required AccessControlRepository accessControlRepository,
    required MoveActivityUseCase moveActivityUseCase,
    required GroupActivitiesByState groupActivitiesByState,
  })  : _activityRepository = activityRepository,
        _stateRepository = stateRepository,
        _accessControlRepository = accessControlRepository,
        _moveActivityUseCase = moveActivityUseCase,
        _groupActivitiesByState = groupActivitiesByState,
        super(const KanbanLoading()) {
    on<LoadBoard>(_onLoadBoard);
    on<MoveActivity>(_onMoveActivity);
    on<ChangeFilter>(_onChangeFilter);
    on<RefreshBoard>(_onRefreshBoard);
    on<ActivitiesUpdated>(_onActivitiesUpdated);
    on<StatesUpdated>(_onStatesUpdated);
  }

  Future<void> _onLoadBoard(
    LoadBoard event,
    Emitter<KanbanBoardState> emit,
  ) async {
    emit(const KanbanLoading());
    _currentSectorId = event.sectorId;
    await _subscribe(event.sectorId);
  }

  Future<void> _onChangeFilter(
    ChangeFilter event,
    Emitter<KanbanBoardState> emit,
  ) async {
    emit(const KanbanLoading());
    _currentSectorId = event.sectorId;
    await _cancelSubscriptions();
    await _subscribe(event.sectorId);
  }

  Future<void> _onRefreshBoard(
    RefreshBoard event,
    Emitter<KanbanBoardState> emit,
  ) async {
    if (_currentSectorId.isEmpty) return;
    emit(const KanbanLoading());
    await _cancelSubscriptions();
    await _subscribe(_currentSectorId);
  }

  Future<void> _onMoveActivity(
    MoveActivity event,
    Emitter<KanbanBoardState> emit,
  ) async {
    try {
      // Check View permission first (req 9.1) — user must be able to see board
      final permissions = await _accessControlRepository.getEffectivePermissions(
        event.movedBy,
        _currentSectorId,
      );

      if (!permissions.contains(Permission.view)) {
        emit(const KanbanError(message: 'Permission denied: insufficient View permission'));
        return;
      }

      // The MoveActivityUseCase handles the Move permission check internally
      await _moveActivityUseCase.execute(
        MoveActivityParams(
          activityId: event.activityId,
          targetStateId: event.targetStateId,
          movedBy: event.movedBy,
        ),
      );
      // Stream will automatically emit updated activities
    } on ActivityTrackerError catch (e) {
      final currentState = state;
      if (currentState is KanbanLoaded) {
        // Re-emit loaded state so the board is preserved, but notify of error
        emit(KanbanError(message: _mapError(e)));
        emit(currentState);
      } else {
        emit(KanbanError(message: _mapError(e)));
      }
    } catch (e) {
      final currentState = state;
      if (currentState is KanbanLoaded) {
        emit(KanbanError(message: e.toString()));
        emit(currentState);
      } else {
        emit(KanbanError(message: e.toString()));
      }
    }
  }

  void _onActivitiesUpdated(
    ActivitiesUpdated event,
    Emitter<KanbanBoardState> emit,
  ) {
    _currentActivities = event.activities;
    _emitGrouped(emit);
  }

  void _onStatesUpdated(
    StatesUpdated event,
    Emitter<KanbanBoardState> emit,
  ) {
    _currentStates = event.states;
    _emitGrouped(emit);
  }

  void _emitGrouped(Emitter<KanbanBoardState> emit) {
    if (_currentStates.isEmpty) return;

    final grouped = _groupActivitiesByState.execute(
      activities: _currentActivities,
      states: _currentStates,
    );

    emit(KanbanLoaded(
      groupedActivities: grouped,
      states: _currentStates,
      currentSectorId: _currentSectorId,
    ));
  }

  Future<void> _subscribe(String sectorId) async {
    // Subscribe to states stream
    _statesSubscription = _stateRepository.watchStates().listen(
      (states) => add(StatesUpdated(states)),
      onError: (error) => add(const RefreshBoard()),
    );

    // Subscribe to activities stream filtered by sector
    _activitiesSubscription =
        _activityRepository.watchActivitiesBySector(sectorId).listen(
      (activities) => add(ActivitiesUpdated(activities)),
      onError: (error) => add(const RefreshBoard()),
    );
  }

  Future<void> _cancelSubscriptions() async {
    await _activitiesSubscription?.cancel();
    _activitiesSubscription = null;
    await _statesSubscription?.cancel();
    _statesSubscription = null;
  }

  String _mapError(ActivityTrackerError error) {
    switch (error) {
      case ActivityTrackerError.permissionDenied:
        return 'Permission denied: you do not have permission to perform this action';
      case ActivityTrackerError.conflictInProgress:
        return 'Cannot modify: a conflict is pending resolution';
      default:
        return 'An error occurred: ${error.name}';
    }
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
