import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/post_category.dart';

/// Firestore DTO for the Post entity.
/// Maps to/from `/activities/{activityId}/posts/{postId}` documents.
class PostModel {
  final String id;
  final String content;
  final String category;
  final String authorId;
  final DateTime createdAt;
  final List<String>? targetSectors;

  const PostModel({
    required this.id,
    required this.content,
    required this.category,
    required this.authorId,
    required this.createdAt,
    this.targetSectors,
  });

  factory PostModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PostModel(
      id: id,
      content: data['content'] as String,
      category: data['category'] as String,
      authorId: data['authorId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
      targetSectors: data['targetSectors'] != null
          ? List<String>.from(data['targetSectors'] as List)
          : null,
    );
  }

  factory PostModel.fromDomain(Post entity) {
    return PostModel(
      id: entity.id,
      content: entity.content,
      category: _categoryToString(entity.category),
      authorId: entity.authorId,
      createdAt: entity.createdAt,
      targetSectors: entity.targetSectors,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'category': category,
      'authorId': authorId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (targetSectors != null) 'targetSectors': targetSectors,
    };
  }

  Post toDomain() {
    return Post(
      id: id,
      content: content,
      category: _parseCategory(category),
      authorId: authorId,
      createdAt: createdAt,
      targetSectors: targetSectors,
    );
  }

  static PostCategory _parseCategory(String value) {
    switch (value) {
      case 'Information':
        return PostCategory.information;
      case 'Complaint':
        return PostCategory.complaint;
      case 'Ask_Help':
        return PostCategory.askHelp;
      default:
        return PostCategory.information;
    }
  }

  static String _categoryToString(PostCategory category) {
    switch (category) {
      case PostCategory.information:
        return 'Information';
      case PostCategory.complaint:
        return 'Complaint';
      case PostCategory.askHelp:
        return 'Ask_Help';
    }
  }
}
