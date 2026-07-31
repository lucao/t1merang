import '../entities/activity.dart';
import '../entities/post.dart';
import '../entities/user_profile.dart';

/// Utility for resolving notification recipients and building notification
/// content for state changes, posts, and Ask_Help requests.
///
/// Notification recipient rules:
/// - State changes: all responsible users minus the acting user
/// - Posts: all responsible users minus the post author
/// - Ask_Help: all users in the target sectors
class ResolveNotificationRecipients {
  /// Resolves recipients for a state change notification.
  ///
  /// Returns a list of user IDs from the activity's responsible users,
  /// excluding the [actingUserId] who performed the state change.
  List<String> resolveForStateChange(Activity activity, String actingUserId) {
    return activity.responsibleUsers
        .where((userId) => userId != actingUserId)
        .toList();
  }

  /// Resolves recipients for a post notification.
  ///
  /// Returns a list of user IDs from the activity's responsible users,
  /// excluding the post's author.
  List<String> resolveForPost(Activity activity, Post post) {
    return activity.responsibleUsers
        .where((userId) => userId != post.authorId)
        .toList();
  }

  /// Resolves recipients for an Ask_Help notification.
  ///
  /// Returns a list of user IDs for all users whose sector is included
  /// in the [targetSectors] list.
  List<String> resolveForAskHelp(
    List<UserProfile> allUsers,
    List<String> targetSectors,
  ) {
    return allUsers
        .where((user) => targetSectors.contains(user.sectorId))
        .map((user) => user.id)
        .toList();
  }

  /// Builds notification content for a state change event.
  ///
  /// Returns a map with:
  /// - `title`: the activity title
  /// - `body`: a descriptive message including the previous state,
  ///   new state, and the name of the user who made the change
  Map<String, String> buildStateChangeContent({
    required String activityTitle,
    required String fromState,
    required String toState,
    required String actingUserName,
  }) {
    return {
      'title': activityTitle,
      'body': '$actingUserName moved activity from $fromState to $toState',
    };
  }

  /// Builds notification content for a discussion post event.
  ///
  /// Returns a map with:
  /// - `title`: the activity title
  /// - `body`: a descriptive message including the author name and
  ///   the post content truncated to a maximum of 200 characters
  Map<String, String> buildPostContent({
    required String activityTitle,
    required String postContent,
    required String authorName,
  }) {
    final truncatedContent = postContent.length > 200
        ? postContent.substring(0, 200)
        : postContent;
    return {
      'title': activityTitle,
      'body': '$authorName: $truncatedContent',
    };
  }
}
