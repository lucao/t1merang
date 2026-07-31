import 'package:equatable/equatable.dart';

/// A single version within a conflict, representing one user's modification.
class ConflictVersion extends Equatable {
  final String versionId;
  final dynamic value;
  final String authorId;
  final DateTime modifiedAt;

  const ConflictVersion({
    required this.versionId,
    required this.value,
    required this.authorId,
    required this.modifiedAt,
  });

  @override
  List<Object?> get props => [versionId, value, authorId, modifiedAt];
}
