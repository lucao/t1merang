import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/post.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/discussion_repository.dart';
import 'package:activity_tracker/domain/use_cases/update_activity_title_use_case.dart';
import 'package:activity_tracker/domain/use_cases/withdraw_responsibility_use_case.dart';
import 'package:activity_tracker/presentation/blocs/activity/activity_bloc.dart';

// --- Mocks ---

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockDiscussionRepository extends Mock implements DiscussionRepository {}

class MockUpdateActivityTitleUseCase extends Mock
    implements UpdateActivityTitleUseCase {}

class MockWithdrawResponsibilityUseCase extends Mock
    implements WithdrawResponsibilityUseCase {}

void main() {
  late MockActivityRepository mockActivityRepository;
  late MockDiscussionRepository mockDiscussionRepository;
  late MockUpdateActivityTitleUseCase mockUpdateActivityTitleUseCase;
  late MockWithdrawResponsibilityUseCase mockWithdrawResponsibilityUseCase;

  final now = DateTime.utc(2024, 1, 15, 10, 0, 0);

  final testActivity = Activity(
    id: 'activity-1',
    title: 'Test Activity',
    currentStateId: 'state-1',
    sectorId: 'sector-1',
    createdAt: now,
    createdBy: 'user-1',
    lastModifiedAt: now,
    lastModifiedBy: 'user-1',
    stateEnteredAt: now,
    responsibleUsers: const ['user-1', 'user-2'],
    isConflicted: false,
    version: 1,
  );

  final testPosts = [
    Post(
      id: 'post-1',
      content: 'First post',
      category: PostCategory.information,
      authorId: 'user-1',
      createdAt: now,
    ),
  ];

  final testTimeline = [
    TimelineEntry(
      id: 'entry-1',
      fromStateId: 'state-0',
      toStateId: 'state-1',
      transitionedAt: now,
      transitionedBy: 'user-1',
      durationMinutes: 60,
    ),
  ];

  setUp(() {
    mockActivityRepository = MockActivityRepository();
    mockDiscussionRepository = MockDiscussionRepository();
    mockUpdateActivityTitleUseCase = MockUpdateActivityTitleUseCase();
    mockWithdrawResponsibilityUseCase = MockWithdrawResponsibilityUseCase();
  });

  ActivityBloc buildBloc() => ActivityBloc(
        activityRepository: mockActivityRepository,
        discussionRepository: mockDiscussionRepository,
        updateActivityTitleUseCase: mockUpdateActivityTitleUseCase,
        withdrawResponsibilityUseCase: mockWithdrawResponsibilityUseCase,
      );

  group('ActivityBloc', () {
    group('LoadActivity', () {
      blocTest<ActivityBloc, ActivityState>(
        'emits [ActivityLoading, ActivityLoaded] and subscribes to streams',
        build: () {
          when(() => mockActivityRepository.getActivity('activity-1'))
              .thenAnswer((_) async => testActivity);
          when(() => mockDiscussionRepository.watchPosts('activity-1'))
              .thenAnswer((_) => Stream.value(testPosts));
          when(() => mockActivityRepository.watchTimeline('activity-1'))
              .thenAnswer((_) => Stream.value(testTimeline));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const LoadActivity(activityId: 'activity-1')),
        expect: () => [
          const ActivityLoading(),
          // Initial loaded state with empty posts/timeline
          ActivityLoaded(
            activity: testActivity,
            posts: const [],
            timeline: const [],
          ),
          // Then posts stream emits
          ActivityLoaded(
            activity: testActivity,
            posts: testPosts,
            timeline: const [],
          ),
          // Then timeline stream emits
          ActivityLoaded(
            activity: testActivity,
            posts: testPosts,
            timeline: testTimeline,
          ),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits [ActivityLoading, ActivityError] when getActivity throws',
        build: () {
          when(() => mockActivityRepository.getActivity('activity-1'))
              .thenThrow(Exception('not found'));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const LoadActivity(activityId: 'activity-1')),
        expect: () => [
          const ActivityLoading(),
          isA<ActivityError>(),
        ],
      );
    });

    group('UpdateTitle', () {
      blocTest<ActivityBloc, ActivityState>(
        'emits updated ActivityLoaded when title update succeeds',
        build: () {
          final updatedActivity = Activity(
            id: 'activity-1',
            title: 'New Title',
            currentStateId: 'state-1',
            sectorId: 'sector-1',
            createdAt: now,
            createdBy: 'user-1',
            lastModifiedAt: now,
            lastModifiedBy: 'user-1',
            stateEnteredAt: now,
            responsibleUsers: const ['user-1', 'user-2'],
            isConflicted: false,
            version: 2,
          );

          when(() => mockUpdateActivityTitleUseCase(
                activityId: 'activity-1',
                newTitle: 'New Title',
                userId: 'user-1',
                sectorId: 'sector-1',
              )).thenAnswer(
              (_) async => UpdateActivityTitleSuccess(updatedActivity));

          return buildBloc();
        },
        seed: () => ActivityLoaded(
          activity: testActivity,
          posts: testPosts,
          timeline: testTimeline,
        ),
        act: (bloc) => bloc.add(const UpdateTitle(
          activityId: 'activity-1',
          newTitle: 'New Title',
          userId: 'user-1',
          sectorId: 'sector-1',
        )),
        expect: () => [
          isA<ActivityLoaded>().having(
            (s) => s.activity.title,
            'title',
            'New Title',
          ),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits ActivityError when title update fails',
        build: () {
          when(() => mockUpdateActivityTitleUseCase(
                activityId: any(named: 'activityId'),
                newTitle: any(named: 'newTitle'),
                userId: any(named: 'userId'),
                sectorId: any(named: 'sectorId'),
              )).thenAnswer((_) async =>
              const UpdateActivityTitleFailure(
                  ActivityTrackerError.permissionDenied));

          return buildBloc();
        },
        seed: () => ActivityLoaded(
          activity: testActivity,
          posts: testPosts,
          timeline: testTimeline,
        ),
        act: (bloc) => bloc.add(const UpdateTitle(
          activityId: 'activity-1',
          newTitle: '',
          userId: 'user-1',
          sectorId: 'sector-1',
        )),
        expect: () => [
          isA<ActivityError>(),
        ],
      );
    });

    group('WithdrawResponsibility', () {
      blocTest<ActivityBloc, ActivityState>(
        'refreshes activity when withdrawal succeeds',
        build: () {
          final updatedActivity = Activity(
            id: 'activity-1',
            title: 'Test Activity',
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
          );

          when(() => mockWithdrawResponsibilityUseCase.execute(
                activityId: 'activity-1',
                userId: 'user-2',
              )).thenAnswer(
              (_) async => const WithdrawResponsibilitySuccess());
          when(() => mockActivityRepository.getActivity('activity-1'))
              .thenAnswer((_) async => updatedActivity);

          return buildBloc();
        },
        seed: () => ActivityLoaded(
          activity: testActivity,
          posts: testPosts,
          timeline: testTimeline,
        ),
        act: (bloc) => bloc.add(const WithdrawResponsibility(
          activityId: 'activity-1',
          userId: 'user-2',
        )),
        expect: () => [
          isA<ActivityLoaded>().having(
            (s) => s.activity.responsibleUsers,
            'responsibleUsers',
            ['user-1'],
          ),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits ActivityError when withdrawal is blocked (last user)',
        build: () {
          when(() => mockWithdrawResponsibilityUseCase.execute(
                activityId: 'activity-1',
                userId: 'user-1',
              )).thenAnswer((_) async =>
              const WithdrawResponsibilityFailure(
                  ActivityTrackerError.withdrawalBlocked));

          return buildBloc();
        },
        seed: () => ActivityLoaded(
          activity: testActivity,
          posts: testPosts,
          timeline: testTimeline,
        ),
        act: (bloc) => bloc.add(const WithdrawResponsibility(
          activityId: 'activity-1',
          userId: 'user-1',
        )),
        expect: () => [
          isA<ActivityError>(),
        ],
      );
    });
  });
}
