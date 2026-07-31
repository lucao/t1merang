import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';
import 'package:activity_tracker/domain/use_cases/resolve_conflict_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = ResolveConflictUseCase();

  Conflict makeConflict({
    required List<ConflictVersion> versions,
    Map<String, String> votes = const {},
  }) {
    return Conflict(
      id: 'conflict-1',
      activityId: 'activity-1',
      fieldPath: 'title',
      status: ConflictStatus.pending,
      createdAt: DateTime(2024, 1, 1),
      votingDeadline: DateTime(2024, 1, 2),
      versions: versions,
      votes: votes,
    );
  }

  group('ResolveConflictUseCase', () {
    test('returns version with most votes (consensus)', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'Title A',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
        ConflictVersion(
          versionId: 'v2',
          value: 'Title B',
          authorId: 'user2',
          modifiedAt: DateTime(2024, 1, 1, 11, 0),
        ),
      ];
      final conflict = makeConflict(
        versions: versions,
        votes: {
          'voter1': 'v1',
          'voter2': 'v1',
          'voter3': 'v2',
        },
      );

      final result = useCase.execute(conflict);

      expect(result.winningVersionId, 'v1');
      expect(result.method, ResolutionMethod.consensus);
    });

    test('falls back to most recent timestamp when no votes cast', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'Title A',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
        ConflictVersion(
          versionId: 'v2',
          value: 'Title B',
          authorId: 'user2',
          modifiedAt: DateTime(2024, 1, 1, 12, 0),
        ),
      ];
      final conflict = makeConflict(versions: versions, votes: {});

      final result = useCase.execute(conflict);

      expect(result.winningVersionId, 'v2');
      expect(result.method, ResolutionMethod.fallback);
    });

    test('breaks tie by most recent timestamp among tied versions', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'Title A',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
        ConflictVersion(
          versionId: 'v2',
          value: 'Title B',
          authorId: 'user2',
          modifiedAt: DateTime(2024, 1, 1, 14, 0),
        ),
        ConflictVersion(
          versionId: 'v3',
          value: 'Title C',
          authorId: 'user3',
          modifiedAt: DateTime(2024, 1, 1, 12, 0),
        ),
      ];
      final conflict = makeConflict(
        versions: versions,
        votes: {
          'voter1': 'v1',
          'voter2': 'v2',
          'voter3': 'v3',
        },
      );

      final result = useCase.execute(conflict);

      // All tied at 1 vote each; v2 has most recent timestamp
      expect(result.winningVersionId, 'v2');
      expect(result.method, ResolutionMethod.consensus);
    });

    test('single version with no votes uses fallback', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'Only version',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
      ];
      final conflict = makeConflict(versions: versions, votes: {});

      final result = useCase.execute(conflict);

      expect(result.winningVersionId, 'v1');
      expect(result.method, ResolutionMethod.fallback);
    });

    test('single version with votes uses consensus', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'Only version',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
      ];
      final conflict = makeConflict(
        versions: versions,
        votes: {'voter1': 'v1'},
      );

      final result = useCase.execute(conflict);

      expect(result.winningVersionId, 'v1');
      expect(result.method, ResolutionMethod.consensus);
    });

    test('throws ArgumentError when versions list is empty', () {
      final conflict = makeConflict(versions: [], votes: {});

      expect(
        () => useCase.execute(conflict),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tie between two of three versions picks most recent among tied', () {
      final versions = [
        ConflictVersion(
          versionId: 'v1',
          value: 'A',
          authorId: 'user1',
          modifiedAt: DateTime(2024, 1, 1, 8, 0),
        ),
        ConflictVersion(
          versionId: 'v2',
          value: 'B',
          authorId: 'user2',
          modifiedAt: DateTime(2024, 1, 1, 15, 0),
        ),
        ConflictVersion(
          versionId: 'v3',
          value: 'C',
          authorId: 'user3',
          modifiedAt: DateTime(2024, 1, 1, 10, 0),
        ),
      ];
      final conflict = makeConflict(
        versions: versions,
        votes: {
          'voter1': 'v1',
          'voter2': 'v1',
          'voter3': 'v2',
          'voter4': 'v2',
          'voter5': 'v3',
        },
      );

      final result = useCase.execute(conflict);

      // v1 has 2 votes, v2 has 2 votes, v3 has 1 vote
      // Tie between v1 and v2; v2 has more recent timestamp
      expect(result.winningVersionId, 'v2');
      expect(result.method, ResolutionMethod.consensus);
    });
  });
}
