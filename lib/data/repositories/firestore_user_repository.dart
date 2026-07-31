import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/params.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';

/// Firestore implementation of [UserRepository].
/// Operates on the `/users/{userId}` collection.
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _activitiesCollection =>
      _firestore.collection('activities');

  @override
  Future<UserProfile> getProfile(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('User not found: $userId');
    }
    return UserModel.fromFirestore(doc.data()!, doc.id).toDomain();
  }

  @override
  Future<void> updateProfile(UpdateProfileParams params) async {
    final updates = <String, dynamic>{};

    if (params.email != null) {
      // Check email uniqueness (case-insensitive)
      final emailLower = params.email!.toLowerCase();
      final existing = await _usersCollection
          .where('email', isEqualTo: emailLower)
          .get();

      final isDuplicate = existing.docs.any((doc) => doc.id != params.userId);
      if (isDuplicate) {
        throw Exception('Email already in use');
      }
      updates['email'] = emailLower;
    }

    if (params.nickname != null) {
      updates['nickname'] = params.nickname;
    }

    if (params.sectorId != null) {
      updates['sectorId'] = params.sectorId;
    }

    if (updates.isNotEmpty) {
      await _usersCollection.doc(params.userId).update(updates);
    }
  }

  @override
  Stream<List<Activity>> watchResponsibleActivities(String userId) {
    return _activitiesCollection
        .where('responsibleUsers', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ActivityModel.fromFirestore(doc.data(), doc.id).toDomain())
            .toList());
  }
}
