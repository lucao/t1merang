import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';
import 'package:activity_tracker/domain/repositories/conflict_repository.dart';
import 'package:activity_tracker/domain/use_cases/cast_vote_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConflictRepository extends Mock implements ConflictRepository {}

void main() {
  late MockConflictRepository mockRepo;
  late CastVoteUseCase useCase;
  late DateTime fixedNow;

  setUp(() {
    mockRepo = MockConflictRepository();
    fixedNow = DateTime.utc(2024, 6, 15, 12, 0, 0);
    useCase = CastVoteUseCase(
      conflictRepository: mockRepo,
      now: () => fixedNow,
    );
  });

  Conflict createConflict({
    Map<String, String> votes = const {},
    DateTime? votingDeadline,
  }) {
    return Conflict(
      id: 'conflict-1',
      activityId: 'activity-1',
      fieldPath: 'title',
      status: ConflictStatus.pending,
      createdAt: DateTime.utc(2024, 6, 14, 12, 0, 0),
      votingDeadline: votingDeadline ?? DateTime.utc(2024, 6, 16, 12, 0, 0),
      versions: [
        ConflictVersion(
          versionId: 'version-1',
          value: 'Title A',
          authorId: 'user-1',
          modifiedAt: DateTime.utc(2024, 6, 14, 11, 0, 0),
        ),
        ConflictVersion(
          versionId: 'version-2',
          value: 'Title B',
          authorId: 'user-2',
          modifiedAt: DateTime.utc(2024, 6, 14, 11, 30, 0),
        ),
      ],
      votes: votes,
    );
  }

  group('CastVoteUseCase', () {
    test('successfully casts a vote when user has not voted and deadline is open', () async {
      final conflict = createConflict();

      when(() => mockRepo.castVote('conflict-1', 'version-1'))
          .thenAnswer((_) async {});

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-1',
      );

      expect(result, isA<CastVoteSuccess>());
      verify(() => mockRepo.castVote('conflict-1', 'version-1')).called(1);
    });

    test('rejects vote when user has already voted', () async {
      final conflict = createConflict(
        votes: {'user-3': 'version-1'},
      );

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-2',
      );

      expect(result, isA<CastVoteFailure>());
      expect(
        (result as CastVoteFailure).error,
        ActivityTrackerError.alreadyVoted,
      );
      verifyNever(() => mockRepo.castVote(any(), any()));
    });

    test('preserves existing vote when duplicate vote is rejected', () async {
      final conflict = createConflict(
        votes: {'user-3': 'version-1'},
      );

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-2',
      );

      expect(result, isA<CastVoteFailure>());
      expect(
        (result as CastVoteFailure).error,
        ActivityTrackerError.alreadyVoted,
      );
      // The existing vote for version-1 remains unchanged
      verifyNever(() => mockRepo.castVote(any(), any()));
    });

    test('rejects vote when voting window has closed', () async {
      final conflict = createConflict(
        votingDeadline: DateTime.utc(2024, 6, 15, 11, 0, 0), // before fixedNow
      );

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-1',
      );

      expect(result, isA<CastVoteFailure>());
      expect(
        (result as CastVoteFailure).error,
        ActivityTrackerError.votingWindowClosed,
      );
      verifyNever(() => mockRepo.castVote(any(), any()));
    });

    test('allows vote exactly at the deadline moment', () async {
      // Deadline is exactly the same as now — not yet "after"
      final conflict = createConflict(
        votingDeadline: fixedNow,
      );

      when(() => mockRepo.castVote('conflict-1', 'version-2'))
          .thenAnswer((_) async {});

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-2',
      );

      expect(result, isA<CastVoteSuccess>());
      verify(() => mockRepo.castVote('conflict-1', 'version-2')).called(1);
    });

    test('checks duplicate vote before checking deadline', () async {
      // User already voted AND deadline has passed
      final conflict = createConflict(
        votes: {'user-3': 'version-1'},
        votingDeadline: DateTime.utc(2024, 6, 15, 11, 0, 0),
      );

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-3',
        versionId: 'version-2',
      );

      // alreadyVoted takes precedence since it's checked first
      expect(result, isA<CastVoteFailure>());
      expect(
        (result as CastVoteFailure).error,
        ActivityTrackerError.alreadyVoted,
      );
    });

    test('different users can vote on the same conflict', () async {
      final conflict = createConflict(
        votes: {'user-1': 'version-1'},
      );

      when(() => mockRepo.castVote('conflict-1', 'version-2'))
          .thenAnswer((_) async {});

      final result = await useCase.execute(
        conflict: conflict,
        userId: 'user-2',
        versionId: 'version-2',
      );

      expect(result, isA<CastVoteSuccess>());
      verify(() => mockRepo.castVote('conflict-1', 'version-2')).called(1);
    });
  });
}
