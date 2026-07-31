import '../entities/post.dart';
import '../entities/post_category.dart';

/// Filters a list of posts by an optional category.
///
/// If [filter] is null, returns all posts (no filtering).
/// If [filter] is specified, returns only posts where the post's category
/// matches the filter. Preserves the original ordering of posts.
class FilterPostsByCategory {
  List<Post> call(List<Post> posts, PostCategory? filter) {
    if (filter == null) {
      return posts;
    }
    return posts.where((post) => post.category == filter).toList();
  }
}
