import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/conflict.dart';
import '../../domain/entities/conflict_status.dart';
import '../../domain/entities/conflict_version.dart';

/// Firestore DTO for the Conflict entity.
/// Maps to/from `/conflicts/{conflictId}` documents.
class ConflictModel {
  final String id;
  final String activityId;
  final String fieldPath;
  final String status;
  final DateTime createdAt;
  final DateTime votingDeadline;
  final DateTime? resolvedAt;
  final String? resolutionMethod;
  final List<ConflictVersionModel> versions;
  final Map<String, String> votes;

  const ConflictModel({
    required this.id,
    required this.activityId,
    required this.fieldPath,
    required this.status,
    required this.createdAt,
    required this.votingDeadline,
    this.resolvedAt,
    this.resolutionMethod,
    required this.versions,
    required this.votes,
  });

  factory ConflictModel.fromFirestore(Map<String, dynamic> data, String id) {
    final versionsData = data['versions'] as List? ?? [];
    final votesData = data['votes'] as Map<String, dynamic>? ?? {};

    return ConflictModel(
      id: id,
      activityId: data['activityId'] as String,
      fieldPath: data['fieldPath'] as String,
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
      votingDeadline: (data['votingDeadline'] as Timestamp).toDate().toUtc(),
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate().toUtc()
          : null,
      resolutionMethod: data['resolutionMethod'] as String?,
      versions: versionsData
          .map((v) =>
              ConflictVersionModel.fromFirestore(v as Map<String, dynamic>))
          .toList(),
      votes: votesData.map((k, v) => MapEntry(k, v as String)),
    );
  }

  factory ConflictModel.fromDomain(Conflict entity) {
    return ConflictModel(
      id: entity.id,
      activityId: entity.activityId,
      fieldPath: entity.fieldPath,
      status: _statusToString(entity.status),
      createdAt: entity.createdAt,
      votingDeadline: entity.votingDeadline,
      versions: entity.versions
          .map((v) => ConflictVersionModel.fromDomain(v))
          .toList(),
      votes: entity.votes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'fieldPath': fieldPath,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'votingDeadline': Timestamp.fromDate(votingDeadline),
      'resolvedAt':
          resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolutionMethod': resolutionMethod,
      'versions': versions.map((v) => v.toFirestore()).toList(),
      'votes': votes,
    };
  }

  Conflict toDomain() {
    return Conflict(
      id: id,
      activityId: activityId,
      fieldPath: fieldPath,
      status: _parseStatus(status),
      createdAt: createdAt,
      votingDeadline: votingDeadline,
      versions: versions.map((v) => v.toDomain()).toList(),
      votes: votes,
    );
  }

  static ConflictStatus _parseStatus(String value) {
    switch (value) {
      case 'pending':
        return ConflictStatus.pending;
      case 'resolved':
        return ConflictStatus.resolved;
      default:
        return ConflictStatus.pending;
    }
  }

  static String _statusToString(ConflictStatus status) {
    switch (status) {
      case ConflictStatus.pending:
        return 'pending';
      case ConflictStatus.resolved:
        return 'resolved';
    }
  }
}

/// Firestore DTO for a single conflict version within a Conflict document.
class ConflictVersionModel {
  final String versionId;
  final dynamic value;
  final String authorId;
  final DateTime modifiedAt;

  const ConflictVersionModel({
    required this.versionId,
    required this.value,
    required this.authorId,
    required this.modifiedAt,
  });

  factory ConflictVersionModel.fromFirestore(Map<String, dynamic> data) {
    return ConflictVersionModel(
      versionId: data['versionId'] as String,
      value: data['value'],
      authorId: data['authorId'] as String,
      modifiedAt: (data['modifiedAt'] as Timestamp).toDate().toUtc(),
    );
  }

  factory ConflictVersionModel.fromDomain(ConflictVersion entity) {
    return ConflictVersionModel(
      versionId: entity.versionId,
      value: entity.value,
      authorId: entity.authorId,
      modifiedAt: entity.modifiedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'versionId': versionId,
      'value': value,
      'authorId': authorId,
      'modifiedAt': Timestamp.fromDate(modifiedAt),
    };
  }

  ConflictVersion toDomain() {
    return ConflictVersion(
      versionId: versionId,
      value: value,
      authorId: authorId,
      modifiedAt: modifiedAt,
    );
  }
}
