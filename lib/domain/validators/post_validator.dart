import '../entities/activity_tracker_error.dart';
import '../entities/post_category.dart';

/// Result type for post validation.
sealed class PostValidationResult {
  const PostValidationResult();
}

/// Successful validation containing the validated post data.
class PostValid extends PostValidationResult {
  final String content;
  final PostCategory category;
  final List<String>? targetSectors;
  const PostValid({
    required this.content,
    required this.category,
    this.targetSectors,
  });
}

/// Failed validation containing the specific error.
class PostInvalid extends PostValidationResult {
  final ActivityTrackerError error;
  const PostInvalid(this.error);
}

/// Validates post creation inputs according to business rules:
/// - Content must be non-empty and between 1–2000 characters → [ActivityTrackerError.postContentRequired]
/// - Category must be provided → [ActivityTrackerError.postContentRequired]
/// - For Ask_Help posts, targetSectors must contain 1–10 items → [ActivityTrackerError.sectorRequired]
class PostValidator {
  const PostValidator();

  /// Validates the given post inputs and returns a [PostValidationResult].
  ///
  /// On success, returns [PostValid] with validated content, category, and target sectors.
  /// On failure, returns [PostInvalid] with the appropriate error code.
  PostValidationResult validate({
    required String? content,
    required PostCategory? category,
    List<String>? targetSectors,
  }) {
    if (content == null || content.isEmpty || content.length > 2000) {
      return const PostInvalid(ActivityTrackerError.postContentRequired);
    }

    if (category == null) {
      return const PostInvalid(ActivityTrackerError.postContentRequired);
    }

    if (category == PostCategory.askHelp) {
      if (targetSectors == null ||
          targetSectors.isEmpty ||
          targetSectors.length > 10) {
        return const PostInvalid(ActivityTrackerError.sectorRequired);
      }
    }

    return PostValid(
      content: content,
      category: category,
      targetSectors: targetSectors,
    );
  }
}
