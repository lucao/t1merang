import 'package:equatable/equatable.dart';

import 'post_category.dart';

/// A single message within an activity's discussion, associated with
/// a category and a user.
class Post extends Equatable {
  final String id;
  final String content;
  final PostCategory category;
  final String authorId;
  final DateTime createdAt;
  final List<String>? targetSectors;

  const Post({
    required this.id,
    required this.content,
    required this.category,
    required this.authorId,
    required this.createdAt,
    this.targetSectors,
  });

  @override
  List<Object?> get props => [
        id,
        content,
        category,
        authorId,
        createdAt,
        targetSectors,
      ];
}
