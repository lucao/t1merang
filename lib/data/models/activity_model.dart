import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/activity.dart';

/// Firestore DTO for the Activity entity.
/// Maps to/from `/activities/{activityId}` documents.
class ActivityModel {
  final String id;
  final String title;
  final String currentStateId;
  final String sectorId;
  final DateTime createdAt;
  final String createdBy;
  final DateTime lastModifiedAt;
  final String lastModifiedBy;
  final DateTime stateEnteredAt;
  final List<String> responsibleUsers;
  final bool isConflicted;
  final int version;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.currentStateId,
    required this.sectorId,
    required this.createdAt,
    required this.createdBy,
    required this.lastModifiedAt,
    required this.lastModifiedBy,
    required this.stateEnteredAt,
    required this.responsibleUsers,
    required this.isConflicted,
    required this.version,
  });

  factory ActivityModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ActivityModel(
      id: id,
      title: data['title'] as String,
      currentStateId: data['currentStateId'] as String,
      sectorId: data['sectorId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
      createdBy: data['createdBy'] as String,
      lastModifiedAt: (data['lastModifiedAt'] as Timestamp).toDate().toUtc(),
      lastModifiedBy: data['lastModifiedBy'] as String,
      stateEnteredAt: (data['stateEnteredAt'] as Timestamp).toDate().toUtc(),
      responsibleUsers: List<String>.from(data['responsibleUsers'] as List),
      isConflicted: data['isConflicted'] as bool,
      version: data['version'] as int,
    );
  }

  factory ActivityModel.fromDomain(Activity entity) {
    return ActivityModel(
      id: entity.id,
      title: entity.title,
      currentStateId: entity.currentStateId,
      sectorId: entity.sectorId,
      createdAt: entity.createdAt,
      createdBy: entity.createdBy,
      lastModifiedAt: entity.lastModifiedAt,
      lastModifiedBy: entity.lastModifiedBy,
      stateEnteredAt: entity.stateEnteredAt,
      responsibleUsers: entity.responsibleUsers,
      isConflicted: entity.isConflicted,
      version: entity.version,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'currentStateId': currentStateId,
      'sectorId': sectorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'lastModifiedAt': Timestamp.fromDate(lastModifiedAt),
      'lastModifiedBy': lastModifiedBy,
      'stateEnteredAt': Timestamp.fromDate(stateEnteredAt),
      'responsibleUsers': responsibleUsers,
      'isConflicted': isConflicted,
      'version': version,
    };
  }

  Activity toDomain() {
    return Activity(
      id: id,
      title: title,
      currentStateId: currentStateId,
      sectorId: sectorId,
      createdAt: createdAt,
      createdBy: createdBy,
      lastModifiedAt: lastModifiedAt,
      lastModifiedBy: lastModifiedBy,
      stateEnteredAt: stateEnteredAt,
      responsibleUsers: responsibleUsers,
      isConflicted: isConflicted,
      version: version,
    );
  }
}
