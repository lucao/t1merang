import 'package:equatable/equatable.dart';

/// A work item on the Kanban board with a title, discussion section,
/// timeline, and assigned state.
class Activity extends Equatable {
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

  const Activity({
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

  @override
  List<Object?> get props => [
        id,
        title,
        currentStateId,
        sectorId,
        createdAt,
        createdBy,
        lastModifiedAt,
        lastModifiedBy,
        stateEnteredAt,
        responsibleUsers,
        isConflicted,
        version,
      ];
}
