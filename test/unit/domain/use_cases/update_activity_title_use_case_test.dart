import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/params.dart';
import 'package:activity_tracker/domain/use_cases/update_activity_title_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

class FakeUpdateActivityParams extends Fake implements UpdateActivityParams {}

void main() {
  late UpdateActivityTitleUseCase useCase;
  late MockActivityRepository mockActivityRepo;
  late MockAccessControlRepository mockAccessControlRepo;

  setUpAll(() {
    registerFallbackValue(FakeUpdateActivityParams());
  });

  setUp(() {
    mockActivityRepo = MockActivityRepository();
    mockAccessControlRepo = MockAccessControlRepository();
    useCase = UpdateActivityTitleUseCase(
      activityRepository: mockActivityRepo,
      accessControlRepository: mockAccessControlRepo,
    );
  });

  Activity createTestActivity({
    String id = 'activity-1',
    String title = 'Original Title',
    bool isConflicted = false,
  }) {
    return Activity(
      id: id,
      title: title,
      currentStateId: 'state-1',
      sectorId: 'sector-1',
      createdAt: DateTime.utc(2024, 1, 1),
      createdBy: 'user-1',
      lastModifiedAt: DateTime.utc(2024, 1, 1),
      lastModifiedBy: 'user-1',
      stateEnteredAt: DateTime.utc(2024, 1, 1),
      responsibleUsers: const ['user-1'],
      isConflicted: isConflicted,
      version: 1,
    );
  }

  group('UpdateActivityTitleUseCase', () {
    const activityId = 'activity-1';
    const userId = 'user-1';
    const sectorId = 'sector-1';

    group('title validation', () {
      test('returns titleRequired when title is empty', () async {
        final result = await useCase(
          activityId: activityId,
          newTitle: '',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleFailure>());
        expect(
          (result as UpdateActivityTitleFailure).error,
          ActivityTrackerError.titleRequired,
        );
        verifyNever(() => mockAccessControlRepo.getEffectivePermissions(
            any(), any()));
      });

      test('returns titleRequired when title is whitespace-only', () async {
        final result = await useCase(
          activityId: activityId,
          newTitle: '   \t\n  ',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleFailure>());
        expect(
          (result as UpdateActivityTitleFailure).error,
          ActivityTrackerError.titleRequired,
        );
      });

      test('returns titleTooLong when title exceeds 200 characters', () async {
        final longTitle = 'a' * 201;
        final result = await useCase(
          activityId: activityId,
          newTitle: longTitle,
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleFailure>());
        expect(
          (result as UpdateActivityTitleFailure).error,
          ActivityTrackerError.titleTooLong,
        );
      });
    });

    group('permission check', () {
      test('returns permissionDenied when user lacks Modify permission',
          () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
            userId, sectorId)).thenAnswer(
          (_) async => {Permission.view, Permission.create},
        );

        final result = await useCase(
          activityId: activityId,
          newTitle: 'Valid Title',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleFailure>());
        expect(
          (result as UpdateActivityTitleFailure).error,
          ActivityTrackerError.permissionDenied,
        );
        verifyNever(() => mockActivityRepo.getActivity(any()));
      });
    });

    group('conflict lock', () {
      test('returns conflictInProgress when activity is conflicted', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
            userId, sectorId)).thenAnswer(
          (_) async => {Permission.modify},
        );
        when(() => mockActivityRepo.getActivity(activityId)).thenAnswer(
          (_) async => createTestActivity(isConflicted: true),
        );

        final result = await useCase(
          activityId: activityId,
          newTitle: 'Valid Title',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleFailure>());
        expect(
          (result as UpdateActivityTitleFailure).error,
          ActivityTrackerError.conflictInProgress,
        );
        verifyNever(
            () => mockActivityRepo.updateActivity(any(), any()));
      });
    });

    group('successful update', () {
      test('persists title change and returns updated activity', () async {
        final originalActivity = createTestActivity();
        final updatedActivity = Activity(
          id: 'activity-1',
          title: 'New Title',
          currentStateId: 'state-1',
          sectorId: 'sector-1',
          createdAt: DateTime.utc(2024, 1, 1),
          createdBy: 'user-1',
          lastModifiedAt: DateTime.utc(2024, 1, 15),
          lastModifiedBy: userId,
          stateEnteredAt: DateTime.utc(2024, 1, 1),
          responsibleUsers: const ['user-1'],
          isConflicted: false,
          version: 2,
        );

        when(() => mockAccessControlRepo.getEffectivePermissions(
            userId, sectorId)).thenAnswer(
          (_) async => {Permission.modify},
        );

        var getCallCount = 0;
        when(() => mockActivityRepo.getActivity(activityId)).thenAnswer((_) {
          getCallCount++;
          return Future.value(
              getCallCount == 1 ? originalActivity : updatedActivity);
        });

        when(() => mockActivityRepo.updateActivity(activityId, any()))
            .thenAnswer((_) async {});

        final result = await useCase(
          activityId: activityId,
          newTitle: 'New Title',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleSuccess>());
        final success = result as UpdateActivityTitleSuccess;
        expect(success.activity.title, 'New Title');
        expect(success.activity.lastModifiedBy, userId);

        verify(() => mockActivityRepo.updateActivity(
              activityId,
              const UpdateActivityParams(
                title: 'New Title',
                modifiedBy: userId,
              ),
            )).called(1);
      });

      test('trims title before persisting', () async {
        final originalActivity = createTestActivity();
        final updatedActivity = Activity(
          id: 'activity-1',
          title: 'Trimmed Title',
          currentStateId: 'state-1',
          sectorId: 'sector-1',
          createdAt: DateTime.utc(2024, 1, 1),
          createdBy: 'user-1',
          lastModifiedAt: DateTime.utc(2024, 1, 15),
          lastModifiedBy: userId,
          stateEnteredAt: DateTime.utc(2024, 1, 1),
          responsibleUsers: const ['user-1'],
          isConflicted: false,
          version: 2,
        );

        when(() => mockAccessControlRepo.getEffectivePermissions(
            userId, sectorId)).thenAnswer(
          (_) async => {Permission.modify},
        );

        var getCallCount = 0;
        when(() => mockActivityRepo.getActivity(activityId)).thenAnswer((_) {
          getCallCount++;
          return Future.value(
              getCallCount == 1 ? originalActivity : updatedActivity);
        });

        when(() => mockActivityRepo.updateActivity(activityId, any()))
            .thenAnswer((_) async {});

        final result = await useCase(
          activityId: activityId,
          newTitle: '  Trimmed Title  ',
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleSuccess>());

        verify(() => mockActivityRepo.updateActivity(
              activityId,
              const UpdateActivityParams(
                title: 'Trimmed Title',
                modifiedBy: userId,
              ),
            )).called(1);
      });

      test('accepts title at exactly 200 characters', () async {
        final title200 = 'a' * 200;
        final originalActivity = createTestActivity();
        final updatedActivity = Activity(
          id: 'activity-1',
          title: title200,
          currentStateId: 'state-1',
          sectorId: 'sector-1',
          createdAt: DateTime.utc(2024, 1, 1),
          createdBy: 'user-1',
          lastModifiedAt: DateTime.utc(2024, 1, 15),
          lastModifiedBy: userId,
          stateEnteredAt: DateTime.utc(2024, 1, 1),
          responsibleUsers: const ['user-1'],
          isConflicted: false,
          version: 2,
        );

        when(() => mockAccessControlRepo.getEffectivePermissions(
            userId, sectorId)).thenAnswer(
          (_) async => {Permission.modify},
        );

        var getCallCount = 0;
        when(() => mockActivityRepo.getActivity(activityId)).thenAnswer((_) {
          getCallCount++;
          return Future.value(
              getCallCount == 1 ? originalActivity : updatedActivity);
        });

        when(() => mockActivityRepo.updateActivity(activityId, any()))
            .thenAnswer((_) async {});

        final result = await useCase(
          activityId: activityId,
          newTitle: title200,
          userId: userId,
          sectorId: sectorId,
        );

        expect(result, isA<UpdateActivityTitleSuccess>());
      });
    });
  });
}
