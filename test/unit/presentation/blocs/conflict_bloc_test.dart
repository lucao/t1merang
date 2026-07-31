import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/conflict.dart';
import 'package:activity_tracker/domain/entities/conflict_status.dart';
import 'package:activity_tracker/domain/entities/conflict_version.dart';
import 'package:activity_tracker/domain/repositories/conflict_repository.dart';
import 'package:activity_tracker/domain/use_cases/cast_vote_use_case.dart';
import 'package:activity_tracker/presentation/blocs/conflict/conflict_bloc.dart';
import 'package:activity_tracker/presentation/blocs/conflict/conflict_event.dart';
import 'package:activity_tracker/presentation/blocs/conflict/conflict_state.dart';

// --- Mocks ---

class MockConflictRepository extends Mock implements ConflictRepository {}

class MockCastVoteUseCase extends Mock implements CastVoteUseCase {}

void main() {
  late MockConflictRepository mockConflictRepository;
  late MockCastVoteUseCase mockCastVoteUseCase;

  final now = DateTime.utc(2024, 1, 15, 10, 0, 0);
  final deadline = now.add(const Duration(hours: 24));

  final testConflict = Conflict(
    id: 'conflict-1',
    activityId: 'activity-1',
    fieldPath: 'title',
    status: ConflictStatus.pending,
    createdAt: now,
    votingDeadline: deadline,
    versions: [
      ConflictVersion(
        versionId: 'v1',
        value: 'Title A',
        authorId: 'user-1',
        modifiedAt: now,
      ),
      ConflictVersion(
        versionId: 'v2',
        value: 'Title B',
        authorId: 'user-2',
        modifiedAt: now.add(const Duration(minutes: 5)),
      ),
    ],
    votes: const {},
  );

  final resolvedConflict = Conflict(
    id: 'conflict-2',
    activityId: 'activity-2',
    fieldPath: 'title',
    status: ConflictStatus.resolved,
    createdAt: now,
    votingDeadline: deadline,
    versions: const [],
    votes: const {},
  );

  setUp(() {
    mockConflictRepository = MockConflictRepository();
    mockCastVoteUseCase = MockCastVoteUseCase();
  });

  ConflictBloc buildBloc() => ConflictBloc(
        conflictRepository: mockConflictRepository,
        castVoteUseCase: mockCastVoteUseCase,
      );

  group('ConflictBloc', () {
    group('LoadConflicts', () {
      blocTest<ConflictBloc, ConflictState>(
        'emits [ConflictLoading, ConflictLoaded] when stream emits conflicts',
        build: () {
          when(() => mockConflictRepository.watchActiveConflicts('user-1'))
              .thenAnswer((_) => Stream.value([testConflict]));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const LoadConflicts(userId: 'user-1')),
        expect: () => [
          const ConflictLoading(),
          ConflictLoaded(conflicts: [testConflict]),
        ],
      );

      blocTest<ConflictBloc, ConflictState>(
        'emits [ConflictLoading, ConflictLoaded] with empty list when no conflicts',
        build: () {
          when(() => mockConflictRepository.watchActiveConflicts('user-1'))
              .thenAnswer((_) => Stream.value([]));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const LoadConflicts(userId: 'user-1')),
        expect: () => [
          const ConflictLoading(),
          const ConflictLoaded(conflicts: []),
        ],
      );

      blocTest<ConflictBloc, ConflictState>(
        'emits [ConflictLoading, ConflictError] when stream errors',
        build: () {
          when(() => mockConflictRepository.watchActiveConflicts('user-1'))
              .thenAnswer((_) => Stream.error(Exception('stream failed')));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const LoadConflicts(userId: 'user-1')),
        expect: () => [
          const ConflictLoading(),
          isA<ConflictError>(),
        ],
      );
    });

    group('CastVote', () {
      blocTest<ConflictBloc, ConflictState>(
        'does not emit error state when vote is cast successfully',
        build: () {
          when(() => mockCastVoteUseCase.execute(
                conflict: testConflict,
                userId: 'user-3',
                versionId: 'v1',
              )).thenAnswer((_) async => const CastVoteSuccess());
          return buildBloc();
        },
        seed: () => ConflictLoaded(conflicts: [testConflict]),
        act: (bloc) => bloc.add(CastVote(
          conflict: testConflict,
          userId: 'user-3',
          versionId: 'v1',
        )),
        expect: () => [],
        verify: (_) {
          verify(() => mockCastVoteUseCase.execute(
                conflict: testConflict,
                userId: 'user-3',
                versionId: 'v1',
              )).called(1);
        },
      );

      blocTest<ConflictBloc, ConflictState>(
        'emits ConflictError when vote fails (already voted)',
        build: () {
          when(() => mockCastVoteUseCase.execute(
                conflict: testConflict,
                userId: 'user-1',
                versionId: 'v1',
              )).thenAnswer(
              (_) async => const CastVoteFailure(ActivityTrackerError.alreadyVoted));
          return buildBloc();
        },
        seed: () => ConflictLoaded(conflicts: [testConflict]),
        act: (bloc) => bloc.add(CastVote(
          conflict: testConflict,
          userId: 'user-1',
          versionId: 'v1',
        )),
        expect: () => [
          isA<ConflictError>().having(
            (s) => s.message,
            'message',
            ActivityTrackerError.alreadyVoted.name,
          ),
        ],
      );
    });

    group('DismissResolved', () {
      blocTest<ConflictBloc, ConflictState>(
        'filters out resolved conflict from loaded conflicts',
        build: () => buildBloc(),
        seed: () => ConflictLoaded(conflicts: [testConflict, resolvedConflict]),
        act: (bloc) =>
            bloc.add(const DismissResolved(conflictId: 'conflict-2')),
        expect: () => [
          ConflictLoaded(conflicts: [testConflict]),
        ],
      );

      blocTest<ConflictBloc, ConflictState>(
        'does not emit new state when conflict is not resolved (no change)',
        build: () => buildBloc(),
        seed: () => ConflictLoaded(conflicts: [testConflict]),
        act: (bloc) =>
            bloc.add(const DismissResolved(conflictId: 'conflict-1')),
        expect: () => [],
      );
    });
  });
}
