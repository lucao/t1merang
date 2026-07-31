part of 'activity_bloc.dart';

/// Events that can be dispatched to the [ActivityBloc].
abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered to load an activity's full details (activity, posts, timeline).
class LoadActivity extends ActivityEvent {
  final String activityId;

  const LoadActivity({required this.activityId});

  @override
  List<Object?> get props => [activityId];
}

/// Triggered when the user edits the activity's title.
class UpdateTitle extends ActivityEvent {
  final String activityId;
  final String newTitle;
  final String userId;
  final String sectorId;

  const UpdateTitle({
    required this.activityId,
    required this.newTitle,
    required this.userId,
    required this.sectorId,
  });

  @override
  List<Object?> get props => [activityId, newTitle, userId, sectorId];
}

/// Triggered when the user creates a new discussion post.
class AddPost extends ActivityEvent {
  final String activityId;
  final CreatePostParams params;

  const AddPost({required this.activityId, required this.params});

  @override
  List<Object?> get props => [activityId, params];
}

/// Triggered when a user withdraws their responsibility from the activity.
class WithdrawResponsibility extends ActivityEvent {
  final String activityId;
  final String userId;

  const WithdrawResponsibility({
    required this.activityId,
    required this.userId,
  });

  @override
  List<Object?> get props => [activityId, userId];
}

/// Internal event triggered when the discussion posts stream emits new data.
class _PostsUpdated extends ActivityEvent {
  final List<Post> posts;

  const _PostsUpdated(this.posts);

  @override
  List<Object?> get props => [posts];
}

/// Internal event triggered when the timeline stream emits new data.
class _TimelineUpdated extends ActivityEvent {
  final List<TimelineEntry> entries;

  const _TimelineUpdated(this.entries);

  @override
  List<Object?> get props => [entries];
}
