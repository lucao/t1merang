import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/conflict.dart';
import '../../domain/repositories/conflict_repository.dart';
import '../models/conflict_model.dart';

/// Firestore implementation of [ConflictRepository].
///
/// Collection path: `/conflicts/{conflictId}`
///
/// - [watchActiveConflicts] streams pending conflicts where the user is a
///   responsible user on the associated activity.
/// - [castVote] records a user's vote using dot-notation update on the
///   `votes` map field.
class FirestoreConflictRepository implements ConflictRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreConflictRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _conflictsCollection =>
      _firestore.collection('conflicts');

  CollectionReference<Map<String, dynamic>> get _activitiesCollection =>
      _firestore.collection('activities');

  /// Watches active (pending) conflicts relevant to a specific user.
  ///
  /// Queries the conflicts collection for documents where status is 'pending',
  /// then filters to only include conflicts whose associated activity has the
  /// given [userId] in its `responsibleUsers` list.
  @override
  Stream<List<Conflict>> watchActiveConflicts(String userId) {
    // First, get activities where the user is responsible
    final activitiesStream = _activitiesCollection
        .where('responsibleUsers', arrayContains: userId)
        .snapshots();

    // Map the activities stream to get their IDs, then query conflicts
    return activitiesStream.asyncMap((activitiesSnapshot) async {
      final activityIds =
          activitiesSnapshot.docs.map((doc) => doc.id).toList();

      if (activityIds.isEmpty) {
        return <Conflict>[];
      }

      // Firestore `whereIn` supports up to 30 values per query.
      // Batch activity IDs into chunks of 30 for the conflict query.
      final conflicts = <Conflict>[];

      for (var i = 0; i < activityIds.length; i += 30) {
        final chunk = activityIds.sublist(
          i,
          i + 30 > activityIds.length ? activityIds.length : i + 30,
        );

        final conflictSnapshot = await _conflictsCollection
            .where('status', isEqualTo: 'pending')
            .where('activityId', whereIn: chunk)
            .get();

        for (final doc in conflictSnapshot.docs) {
          final model = ConflictModel.fromFirestore(doc.data(), doc.id);
          conflicts.add(model.toDomain());
        }
      }

      return conflicts;
    });
  }

  /// Casts a vote for a specific version in a conflict.
  ///
  /// Uses Firestore dot-notation (`votes.{userId}`) to atomically set the
  /// user's vote without overwriting other users' votes.
  ///
  /// Throws [StateError] if no user is currently authenticated.
  @override
  Future<void> castVote(String conflictId, String versionId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user. Cannot cast vote.');
    }

    final userId = currentUser.uid;

    await _conflictsCollection.doc(conflictId).update({
      'votes.$userId': versionId,
    });
  }
}
