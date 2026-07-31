import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/timeline_entry.dart';

/// Firestore DTO for the TimelineEntry entity.
/// Maps to/from `/activities/{activityId}/timeline/{entryId}` documents.
class TimelineEntryModel {
  final String id;
  final String fromStateId;
  final String toStateId;
  final DateTime transitionedAt;
  final String transitionedBy;
  final int durationMinutes;

  const TimelineEntryModel({
    required this.id,
    required this.fromStateId,
    required this.toStateId,
    required this.transitionedAt,
    required this.transitionedBy,
    required this.durationMinutes,
  });

  factory TimelineEntryModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return TimelineEntryModel(
      id: id,
      fromStateId: data['fromStateId'] as String,
      toStateId: data['toStateId'] as String,
      transitionedAt: (data['transitionedAt'] as Timestamp).toDate().toUtc(),
      transitionedBy: data['transitionedBy'] as String,
      durationMinutes: data['durationMinutes'] as int,
    );
  }

  factory TimelineEntryModel.fromDomain(TimelineEntry entity) {
    return TimelineEntryModel(
      id: entity.id,
      fromStateId: entity.fromStateId,
      toStateId: entity.toStateId,
      transitionedAt: entity.transitionedAt,
      transitionedBy: entity.transitionedBy,
      durationMinutes: entity.durationMinutes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromStateId': fromStateId,
      'toStateId': toStateId,
      'transitionedAt': Timestamp.fromDate(transitionedAt),
      'transitionedBy': transitionedBy,
      'durationMinutes': durationMinutes,
    };
  }

  TimelineEntry toDomain() {
    return TimelineEntry(
      id: id,
      fromStateId: fromStateId,
      toStateId: toStateId,
      transitionedAt: transitionedAt,
      transitionedBy: transitionedBy,
      durationMinutes: durationMinutes,
    );
  }
}
