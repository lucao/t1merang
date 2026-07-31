import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/post.dart';
import '../../../domain/entities/timeline_entry.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/repositories/discussion_repository.dart';
import '../../../domain/repositories/params.dart';
import '../../../domain/use_cases/update_activity_title_use_case.dart';
import '../../../domain/use_cases/withdraw_responsibility_use_case.dart';

part 'activity_event.dart';
part 'activity_state.dart';

/// BLoC for managing individual activity detail state including
/// discussion posts, timeline entries, and responsible users.
///
/// Subscribes to real-time updates for discussion posts and timeline
/// via stream subscriptions that are cancelled on close.
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final ActivityRepository _activityRepository;
  final DiscussionRepository _discussionRepository;
  final UpdateActivityTitleUseCase _updateActivityTitleUseCase;
  final WithdrawResponsibilityUseCase _withdrawResponsibilityUseCase;

  StreamSubscription<List<Post>>? _postsSubscription;
  StreamSubscription<List<TimelineEntry>>? _timelineSubscription;

  ActivityBloc({
    required ActivityRepository activityRepository,
    required DiscussionRepository discussionRepository,
    required UpdateActivityTitleUseCase updateActivityTitleUseCase,
    required WithdrawResponsibilityUseCase withdrawResponsibilityUseCase,
  })  : _activityRepository = activityRepository,
        _discussionRepository = discussionRepository,
        _updateActivityTitleUseCase = updateActivityTitleUseCase,
        _withdrawResponsibilityUseCase = withdrawResponsibilityUseCase,
        super(const ActivityLoading()) {
    on<LoadActivity>(_onLoadActivity);
    on<UpdateTitle>(_onUpdateTitle);
    on<AddPost>(_onAddPost);
    on<WithdrawResponsibility>(_onWithdrawResponsibility);
    on<_PostsUpdated>(_onPostsUpdated);
    on<_TimelineUpdated>(_onTimelineUpdated);
  }

  Future<void> _onLoadActivity(
    LoadActivity event,
    Emitter<ActivityState> emit,
  ) async {
    emit(const ActivityLoading());

    try {
      final activity =
          await _activityRepository.getActivity(event.activityId);

      emit(ActivityLoaded(
        activity: activity,
        posts: const [],
        timeline: const [],
      ));

      // Subscribe to real-time discussion updates.
      await _postsSubscription?.cancel();
      _postsSubscription = _discussionRepository
          .watchPosts(event.activityId)
          .listen(
            (posts) => add(_PostsUpdated(posts)),
            onError: (_) {/* handled via stream; keep subscription alive */},
          );

      // Subscribe to real-time timeline updates.
      await _timelineSubscription?.cancel();
      _timelineSubscription = _activityRepository
          .watchTimeline(event.activityId)
          .listen(
            (entries) => add(_TimelineUpdated(entries)),
            onError: (_) {/* handled via stream; keep subscription alive */},
          );
    } catch (e) {
      emit(ActivityError(message: e.toString()));
    }
  }

  Future<void> _onUpdateTitle(
    UpdateTitle event,
    Emitter<ActivityState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ActivityLoaded) return;

    final result = await _updateActivityTitleUseCase(
      activityId: event.activityId,
      newTitle: event.newTitle,
      userId: event.userId,
      sectorId: event.sectorId,
    );

    switch (result) {
      case UpdateActivityTitleSuccess(:final activity):
        emit(currentState.copyWith(activity: activity));
      case UpdateActivityTitleFailure(:final error):
        emit(ActivityError(message: error.name));
    }
  }

  Future<void> _onAddPost(
    AddPost event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is! ActivityLoaded) return;

    try {
      await _discussionRepository.createPost(event.activityId, event.params);
      // The new post will arrive via the watchPosts stream subscription.
    } catch (e) {
      emit(ActivityError(message: e.toString()));
    }
  }

  Future<void> _onWithdrawResponsibility(
    WithdrawResponsibility event,
    Emitter<ActivityState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ActivityLoaded) return;

    final result = await _withdrawResponsibilityUseCase.execute(
      activityId: event.activityId,
      userId: event.userId,
    );

    switch (result) {
      case WithdrawResponsibilitySuccess():
        // Refresh the activity to reflect updated responsible users.
        try {
          final updatedActivity =
              await _activityRepository.getActivity(event.activityId);
          emit(currentState.copyWith(activity: updatedActivity));
        } catch (e) {
          emit(ActivityError(message: e.toString()));
        }
      case WithdrawResponsibilityFailure(:final error):
        emit(ActivityError(message: error.name));
    }
  }

  void _onPostsUpdated(
    _PostsUpdated event,
    Emitter<ActivityState> emit,
  ) {
    final currentState = state;
    if (currentState is ActivityLoaded) {
      emit(currentState.copyWith(posts: event.posts));
    }
  }

  void _onTimelineUpdated(
    _TimelineUpdated event,
    Emitter<ActivityState> emit,
  ) {
    final currentState = state;
    if (currentState is ActivityLoaded) {
      emit(currentState.copyWith(timeline: event.entries));
    }
  }

  @override
  Future<void> close() async {
    await _postsSubscription?.cancel();
    await _timelineSubscription?.cancel();
    return super.close();
  }
}
