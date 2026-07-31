import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

/// Firestore + FCM implementation of [NotificationRepository].
///
/// Uses the `/notifications/{notificationId}` collection for notification
/// documents and Firebase Cloud Messaging for push token management.
///
/// Features:
/// - Real-time notification stream via [watchNotifications]
/// - Mark-as-read updates via [markAsRead]
/// - In-app notification creation via [sendNotification]
/// - FCM token subscription and storage on user documents
class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  /// Reference to the top-level notifications collection.
  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  /// Reference to the top-level users collection (for token storage).
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  FirestoreNotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                NotificationModel.fromFirestore(doc.data(), doc.id).toDomain())
            .toList());
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'read': true});
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String type,
    required String activityId,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final docRef = _notificationsRef.doc();

    final model = NotificationModel(
      id: docRef.id,
      userId: userId,
      type: type,
      activityId: activityId,
      title: title,
      body: body,
      read: false,
      createdAt: now,
    );

    await docRef.set(model.toFirestore());
  }

  // --- FCM Token Management ---

  /// Retrieves the current FCM token and stores it on the user document.
  /// Should be called after authentication.
  Future<void> registerFcmToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _storeFcmToken(userId, token);
    }
  }

  /// Subscribes to FCM token refresh events and stores updated tokens
  /// on the user document. Returns the stream subscription so the caller
  /// can cancel it when the user logs out.
  Stream<String> onTokenRefresh() {
    return _messaging.onTokenRefresh;
  }

  /// Stores or updates the FCM token on the user document.
  Future<void> _storeFcmToken(String userId, String token) async {
    await _usersRef.doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the stored FCM token for the given user.
  /// Intended to be called from the token refresh listener.
  Future<void> updateFcmToken(String userId, String token) async {
    await _storeFcmToken(userId, token);
  }

  /// Removes the FCM token from the user document.
  /// Should be called on logout.
  Future<void> removeFcmToken(String userId) async {
    await _usersRef.doc(userId).update({
      'fcmToken': FieldValue.delete(),
      'fcmTokenUpdatedAt': FieldValue.delete(),
    });
  }
}
