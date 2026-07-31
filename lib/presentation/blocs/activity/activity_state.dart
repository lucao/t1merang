part of 'activity_bloc.dart';

/// States emitted by the [ActivityBloc].
abstract class ActivityState extends Equatable {
  const ActivityState();

  @override
  List<Object?> get props => [];
}

/// The activity detail is being loaded.
class ActivityLoading extends ActivityState {
  const ActivityLoading();
}

/// The activity detail has been loaded successfully.
class ActivityLoaded extends ActivityState {
  final Activity activity;
  final List<Post> posts;
  final List<TimelineEntry> timeline;

  const ActivityLoaded({
    required this.activity,
    required this.posts,
    required this.timeline,
  });

  @override
  List<Object?> get props => [activity, posts, timeline];

  /// Creates a copy with optional overrides.
  ActivityLoaded copyWith({
    Activity? activity,
    List<Post>? posts,
    List<TimelineEntry>? timeline,
  }) {
    return ActivityLoaded(
      activity: activity ?? this.activity,
      posts: posts ?? this.posts,
      timeline: timeline ?? this.timeline,
    );
  }
}

/// An error occurred while loading or modifying the activity.
class ActivityError extends ActivityState {
  final String message;

  const ActivityError({required this.message});

  @override
  List<Object?> get props => [message];
}
