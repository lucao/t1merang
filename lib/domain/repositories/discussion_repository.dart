import '../entities/post.dart';
import '../entities/post_category.dart';
import 'params.dart';

/// Abstract repository for managing discussion posts on activities.
abstract class DiscussionRepository {
  /// Watches posts for a specific activity, optionally filtered by category.
  Stream<List<Post>> watchPosts(String activityId, {PostCategory? filter});

  /// Creates a new discussion post on an activity.
  Future<Post> createPost(String activityId, CreatePostParams params);
}
