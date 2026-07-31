import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/kanban_state.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/entities/sort_order.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/state_repository.dart';
import 'package:activity_tracker/domain/use_cases/group_activities_by_state.dart';
import 'package:activity_tracker/domain/use_cases/move_activity_use_case.dart';
import 'package:activity_tracker/presentation/blocs/kanban/kanban_bloc.dart';
import 'package:activity_tracker/presentation/blocs/kanban/kanban_event.dart';
import 'package:activity_tracker/presentation/blocs/kanban/kanban_state.dart';

// --- Mocks ---

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockStateRepository extends Mock implements StateRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

class MockMoveActivityUseCase extends Mock implements MoveActivityUseCase {}

class MockGroupActivitiesByState extends Mock
    implements GroupActivitiesByState {}

class FakeMoveActivityParams extends Fake implements MoveActivityParams {}

void main() {
  late MockActivityRepository mockActivityRepository;
  late MockStateRepository mockStateRepository;
  late MockAccessControlRepository mockAccessControlRepository;
  late MockMoveActivityUseCase mockMoveActivityUseCase;
  late MockGroupActivitiesByState mockGroupActivitiesByState;

  final now = DateTime.utc(2024, 1, 15, 10, 0, 0);

  final testStates = [
    const KanbanState(
      id: 'state-1',
      name: 'Backlog',
      order: 0,
      sortOrder: SortOrder.oldestFirst,
      isDefault: true,
    ),
    const KanbanState(
      id: 'state-2',
      name: 'Development',
      order: 1,
      sortOrder: SortOrder.newestFirst,
      isDefault: false,
    ),
  ];

  final testActivities = [
    Activity(
      id: 'activity-1',
      title: 'Fix bug',
      currentStateId: 'state-1',
      sectorId: 'sector-1',
      createdAt: now,
      createdBy: 'user-1',
      lastModifiedAt: now,
      lastModifiedBy: 'user-1',
      stateEnteredAt: now,
      responsibleUsers: const ['user-1'],
      isConflicted: false,
      version: 1,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(FakeMoveActivityParams());
  });

  setUp(() {
    mockActivityRepository = MockActivityRepository();
    mockStateRepository = MockStateRepository();
    mockAccessControlRepository = MockAccessControlRepository();
    mockMoveActivityUseCase = MockMoveActivityUseCase();
    mockGroupActivitiesByState = MockGroupActivitiesByState();
  });

  KanbanBloc buildBloc() => KanbanBloc(
        activityRepository: mockActivityRepository,
        stateRepository: mockStateRepository,
        accessControlRepository: mockAccessControlRepository,
        moveActivityUseCase: mockMoveActivityUseCase,
        groupActivitiesByState: mockGroupActivitiesByState,
      );

  group('KanbanBloc', () {
    group('LoadBoard', () {
      blocTest<KanbanBloc, KanbanBoardState>(
        'emits [KanbanLoading, KanbanLoaded] when streams emit data',
        build: () {
          when(() => mockStateRepository.watchStates())
              .thenAnswer((_) => Stream.value(testStates));
          when(() => mockActivityRepository.watchActivitiesBySector('sector-1'))
              .thenAnswer((_) => Stream.value(testActivities));
          when(() => mockGroupActivitiesByState.execute(
                activities: any(named: 'activities'),
                states: any(named: 'states'),
              )).thenReturn({'state-1': testActivities, 'state-2': <Activity>[]});
          return buildBloc();
        },
        act: (bloc) => bloc.add(const LoadBoard(sectorId: 'sector-1')),
        expect: () => [
          const KanbanLoading(),
          isA<KanbanLoaded>()
              .having((s) => s.currentSectorId, 'currentSectorId', 'sector-1')
              .having((s) => s.states, 'states', testStates),
        ],
      );

      blocTest<KanbanBloc, KanbanBoardState>(
        'emits [KanbanLoading] but does not emit loaded when states stream is empty',
        build: () {
          when(() => mockStateRepository.watchStates())
              .thenAnswer((_) => Stream.value([]));
          when(() => mockActivityRepository.watchActivitiesBySector('sector-1'))
              .thenAnswer((_) => Stream.value(testActivities));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const LoadBoard(sectorId: 'sector-1')),
        expect: () => [
          const KanbanLoading(),
          // _emitGrouped returns early when states are empty
        ],
      );
    });

    group('MoveActivity', () {
      blocTest<KanbanBloc, KanbanBoardState>(
        'delegates move to MoveActivityUseCase when user has View permission',
        build: () {
          when(() => mockAccessControlRepository.getEffectivePermissions(
                'user-1',
                'sector-1',
              )).thenAnswer(
              (_) async => {Permission.view, Permission.move});
          when(() => mockMoveActivityUseCase.execute(any()))
              .thenAnswer((_) async => MoveActivityResult(
                    activityId: 'activity-1',
                    fromStateId: 'state-1',
                    toStateId: 'state-2',
                    transitionedAt: now,
                    durationMinutes: 10,
                    responsibleUsers: ['user-1'],
                  ));

          // Set up streams for initial load
          when(() => mockStateRepository.watchStates())
              .thenAnswer((_) => Stream.value(testStates));
          when(() => mockActivityRepository.watchActivitiesBySector('sector-1'))
              .thenAnswer((_) => Stream.value(testActivities));
          when(() => mockGroupActivitiesByState.execute(
                activities: any(named: 'activities'),
                states: any(named: 'states'),
              )).thenReturn({'state-1': testActivities, 'state-2': <Activity>[]});

          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const LoadBoard(sectorId: 'sector-1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const MoveActivity(
            activityId: 'activity-1',
            targetStateId: 'state-2',
            movedBy: 'user-1',
          ));
        },
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(() => mockMoveActivityUseCase.execute(any())).called(1);
        },
      );

      blocTest<KanbanBloc, KanbanBoardState>(
        'emits KanbanError when user lacks View permission',
        build: () {
          when(() => mockAccessControlRepository.getEffectivePermissions(
                'user-1',
                'sector-1',
              )).thenAnswer((_) async => <Permission>{});

          // Set up streams
          when(() => mockStateRepository.watchStates())
              .thenAnswer((_) => Stream.value(testStates));
          when(() => mockActivityRepository.watchActivitiesBySector('sector-1'))
              .thenAnswer((_) => Stream.value(testActivities));
          when(() => mockGroupActivitiesByState.execute(
                activities: any(named: 'activities'),
                states: any(named: 'states'),
              )).thenReturn({'state-1': testActivities, 'state-2': <Activity>[]});

          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const LoadBoard(sectorId: 'sector-1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const MoveActivity(
            activityId: 'activity-1',
            targetStateId: 'state-2',
            movedBy: 'user-1',
          ));
        },
        wait: const Duration(milliseconds: 100),
        skip: 2, // Skip KanbanLoading and KanbanLoaded from LoadBoard
        expect: () => [
          isA<KanbanError>().having(
            (s) => s.message,
            'message',
            contains('Permission denied'),
          ),
        ],
      );
    });

    group('ChangeFilter', () {
      blocTest<KanbanBloc, KanbanBoardState>(
        'emits [KanbanLoading] then re-subscribes to new sector',
        build: () {
          when(() => mockStateRepository.watchStates())
              .thenAnswer((_) => Stream.value(testStates));
          when(() => mockActivityRepository.watchActivitiesBySector('sector-2'))
              .thenAnswer((_) => Stream.value(<Activity>[]));
          when(() => mockGroupActivitiesByState.execute(
                activities: any(named: 'activities'),
                states: any(named: 'states'),
              )).thenReturn({'state-1': <Activity>[], 'state-2': <Activity>[]});
          return buildBloc();
        },
        seed: () => KanbanLoaded(
          groupedActivities: {'state-1': testActivities, 'state-2': []},
          states: testStates,
          currentSectorId: 'sector-1',
        ),
        act: (bloc) => bloc.add(const ChangeFilter(sectorId: 'sector-2')),
        expect: () => [
          const KanbanLoading(),
          isA<KanbanLoaded>()
              .having((s) => s.currentSectorId, 'currentSectorId', 'sector-2'),
        ],
      );
    });
  });
}
