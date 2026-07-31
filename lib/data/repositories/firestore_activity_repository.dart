import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/params.dart';
import '../models/activity_model.dart';
import '../models/timeline_entry_model.dart';

/// Firestore implementation of [ActivityRepository].
///
/// Uses the `/activities/{activityId}` collection for activity documents
/// and `/activities/{activityId}/timeline/{entryId}` subcollection for
/// timeline entries.
///
/// Supports:
/// - Real-time snapshots via [watchActivitiesBySector]
/// - Optimistic concurrency control via the `version` field
/// - Offline write queuing via Firestore's built-in persistence
class FirestoreActivityRepository implements ActivityRepository {
  final FirebaseFirestore _firestore;

  /// Reference to the top-level activities collection.
  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _firestore.collection('activities');

  FirestoreActivityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<Activity>> watchActivitiesBySector(String sectorId) {
    return _activitiesRef
        .where('sectorId', isEqualTo: sectorId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityModel.fromFirestore(doc.data(), doc.id).toDomain())
            .toList());
  }

  @override
  Future<Activity> createActivity(CreateActivityParams params) async {
    final now = DateTime.now().toUtc();
    // Truncate to second precision
    final timestamp = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    final docRef = _activitiesRef.doc();

    final model = ActivityModel(
      id: docRef.id,
      title: params.title,
      currentStateId: 'backlog',
      sectorId: params.sectorId,
      createdAt: timestamp,
      createdBy: params.createdBy,
      lastModifiedAt: timestamp,
      lastModifiedBy: params.createdBy,
      stateEnteredAt: timestamp,
      responsibleUsers: [params.createdBy],
      isConflicted: false,
      version: 1,
    );

    await docRef.set(model.toFirestore());

    return model.toDomain();
  }

  @override
  Future<void> updateActivity(
    String activityId,
    UpdateActivityParams params,
  ) async {
    final docRef = _activitiesRef.doc(activityId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Activity $activityId not found');
      }

      final data = snapshot.data()!;
      final currentVersion = data['version'] as int;

      final updates = <String, dynamic>{
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': params.modifiedBy,
        'version': currentVersion + 1,
      };

      if (params.title != null) {
        updates['title'] = params.title;
      }

      transaction.update(docRef, updates);
    });
  }

  @override
  Future<void> moveActivity(
    String activityId,
    String targetStateId, {
    required DateTime stateEnteredAt,
    required List<String> responsibleUsers,
    required String movedBy,
  }) async {
    final docRef = _activitiesRef.doc(activityId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Activity $activityId not found');
      }

      final data = snapshot.data()!;
      final currentVersion = data['version'] as int;

      transaction.update(docRef, {
        'currentStateId': targetStateId,
        'stateEnteredAt': Timestamp.fromDate(stateEnteredAt),
        'responsibleUsers': responsibleUsers,
        'lastModifiedAt': Timestamp.fromDate(stateEnteredAt),
        'lastModifiedBy': movedBy,
        'version': currentVersion + 1,
      });
    });
  }

  @override
  Future<Activity> getActivity(String activityId) async {
    final snapshot = await _activitiesRef.doc(activityId).get();
    if (!snapshot.exists) {
      throw StateError('Activity $activityId not found');
    }
    return ActivityModel.fromFirestore(snapshot.data()!, snapshot.id).toDomain();
  }

  @override
  Stream<List<TimelineEntry>> watchTimeline(String activityId) {
    return _activitiesRef
        .doc(activityId)
        .collection('timeline')
        .orderBy('transitionedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TimelineEntryModel.fromFirestore(doc.data(), doc.id).toDomain())
            .toList());
  }

  @override
  Future<void> addTimelineEntry(String activityId, TimelineEntry entry) async {
    final timelineRef =
        _activitiesRef.doc(activityId).collection('timeline').doc(entry.id);

    final model = TimelineEntryModel.fromDomain(entry);
    await timelineRef.set(model.toFirestore());
  }

  @override
  Future<void> withdrawResponsibility(
    String activityId,
    String userId,
  ) async {
    final docRef = _activitiesRef.doc(activityId);

    await docRef.update({
      'responsibleUsers': FieldValue.arrayRemove([userId]),
    });
  }
}
