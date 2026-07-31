import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/post_category.dart';
import '../../domain/repositories/discussion_repository.dart';
import '../../domain/repositories/params.dart';
import '../models/post_model.dart';

/// Firestore implementation of [DiscussionRepository].
///
/// Posts are stored as subcollection documents at:
/// `/activities/{activityId}/posts/{postId}`
class FirestoreDiscussionRepository implements DiscussionRepository {
  final FirebaseFirestore _firestore;

  FirestoreDiscussionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _postsCollection(
      String activityId) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('posts');
  }

  @override
  Stream<List<Post>> watchPosts(String activityId, {PostCategory? filter}) {
    Query<Map<String, dynamic>> query = _postsCollection(activityId);

    if (filter != null) {
      query = query.where('category', isEqualTo: _categoryToString(filter));
    }

    query = query.orderBy('createdAt');

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final model = PostModel.fromFirestore(doc.data(), doc.id);
        return model.toDomain();
      }).toList();
    });
  }

  @override
  Future<Post> createPost(String activityId, CreatePostParams params) async {
    final now = DateTime.now().toUtc();

    final postData = <String, dynamic>{
      'content': params.content,
      'category': _categoryToString(params.category),
      'authorId': params.authorId,
      'createdAt': Timestamp.fromDate(now),
      if (params.targetSectors != null) 'targetSectors': params.targetSectors,
    };

    final docRef = await _postsCollection(activityId).add(postData);

    return Post(
      id: docRef.id,
      content: params.content,
      category: params.category,
      authorId: params.authorId,
      createdAt: now,
      targetSectors: params.targetSectors,
    );
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
