import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/params.dart';
import 'package:activity_tracker/domain/use_cases/create_activity_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

void main() {
  late MockActivityRepository mockActivityRepo;
  late MockAccessControlRepository mockAccessControlRepo;
  late CreateActivityUseCase useCase;

  setUp(() {
    mockActivityRepo = MockActivityRepository();
    mockAccessControlRepo = MockAccessControlRepository();
    useCase = CreateActivityUseCase(
      activityRepository: mockActivityRepo,
      accessControlRepository: mockAccessControlRepo,
    );
  });

  setUpAll(() {
    registerFallbackValue(const CreateActivityParams(
      title: '',
      sectorId: '',
      createdBy: '',
    ));
  });

  Activity _createSampleActivity({
    String title = 'Test Activity',
    String createdBy = 'user-1',
    String sectorId = 'sector-1',
  }) {
    final now = DateTime.now().toUtc();
    final truncated = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    return Activity(
      id: 'activity-1',
      title: title,
      currentStateId: 'backlog',
      sectorId: sectorId,
      createdAt: truncated,
      createdBy: createdBy,
      lastModifiedAt: truncated,
      lastModifiedBy: createdBy,
      stateEnteredAt: truncated,
      responsibleUsers: [createdBy],
      isConflicted: false,
      version: 1,
    );
  }

  group('CreateActivityUseCase', () {
    group('title validation', () {
      test('rejects empty title with titleRequired error', () async {
        final params = const CreateActivityParams(
          title: '',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivityFailure>());
        expect(
          (result as CreateActivityFailure).error,
          ActivityTrackerError.titleRequired,
        );
        verifyNever(() => mockAccessControlRepo.getEffectivePermissions(
              any(),
              any(),
            ));
      });

      test('rejects whitespace-only title with titleRequired error', () async {
        final params = const CreateActivityParams(
          title: '   ',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivityFailure>());
        expect(
          (result as CreateActivityFailure).error,
          ActivityTrackerError.titleRequired,
        );
      });

      test('rejects title exceeding 200 characters with titleTooLong error',
          () async {
        final params = CreateActivityParams(
          title: 'a' * 201,
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivityFailure>());
        expect(
          (result as CreateActivityFailure).error,
          ActivityTrackerError.titleTooLong,
        );
      });
    });

    group('permission check', () {
      test('rejects when user lacks Create permission', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.view, Permission.move});

        final params = const CreateActivityParams(
          title: 'Valid Title',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivityFailure>());
        expect(
          (result as CreateActivityFailure).error,
          ActivityTrackerError.permissionDenied,
        );
        verifyNever(() => mockActivityRepo.createActivity(any()));
      });

      test('rejects when user has no permissions at all', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => <Permission>{});

        final params = const CreateActivityParams(
          title: 'Valid Title',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivityFailure>());
        expect(
          (result as CreateActivityFailure).error,
          ActivityTrackerError.permissionDenied,
        );
      });
    });

    group('successful creation', () {
      test('creates activity when title is valid and user has Create permission',
          () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.create});

        final expectedActivity = _createSampleActivity();
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async => expectedActivity);

        final params = const CreateActivityParams(
          title: 'Valid Title',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        expect(result, isA<CreateActivitySuccess>());
        expect((result as CreateActivitySuccess).activity, expectedActivity);
      });

      test('passes trimmed title to repository', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.create});

        final expectedActivity =
            _createSampleActivity(title: 'Trimmed Title');
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async => expectedActivity);

        final params = const CreateActivityParams(
          title: '  Trimmed Title  ',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        await useCase.execute(params);

        final captured =
            verify(() => mockActivityRepo.createActivity(captureAny()))
                .captured
                .single as CreateActivityParams;
        expect(captured.title, 'Trimmed Title');
        expect(captured.sectorId, 'sector-1');
        expect(captured.createdBy, 'user-1');
      });

      test('created activity has creator in responsibleUsers', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.create});

        final expectedActivity = _createSampleActivity();
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async => expectedActivity);

        final params = const CreateActivityParams(
          title: 'My Task',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        final activity = (result as CreateActivitySuccess).activity;
        expect(activity.responsibleUsers, contains('user-1'));
      });

      test('created activity is placed in Backlog state', () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.create});

        final expectedActivity = _createSampleActivity();
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async => expectedActivity);

        final params = const CreateActivityParams(
          title: 'My Task',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        final activity = (result as CreateActivitySuccess).activity;
        expect(activity.currentStateId, 'backlog');
      });

      test('created activity has UTC timestamp with second precision',
          () async {
        when(() => mockAccessControlRepo.getEffectivePermissions(
              'user-1',
              'sector-1',
            )).thenAnswer((_) async => {Permission.create});

        final now = DateTime.now().toUtc();
        final truncated = DateTime.utc(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        );
        final expectedActivity = Activity(
          id: 'activity-1',
          title: 'My Task',
          currentStateId: 'backlog',
          sectorId: 'sector-1',
          createdAt: truncated,
          createdBy: 'user-1',
          lastModifiedAt: truncated,
          lastModifiedBy: 'user-1',
          stateEnteredAt: truncated,
          responsibleUsers: const ['user-1'],
          isConflicted: false,
          version: 1,
        );
        when(() => mockActivityRepo.createActivity(any()))
            .thenAnswer((_) async => expectedActivity);

        final params = const CreateActivityParams(
          title: 'My Task',
          sectorId: 'sector-1',
          createdBy: 'user-1',
        );

        final result = await useCase.execute(params);

        final activity = (result as CreateActivitySuccess).activity;
        expect(activity.createdAt.isUtc, isTrue);
        // Second precision: microsecond and millisecond should be zero
        expect(activity.createdAt.microsecond, 0);
        expect(activity.createdAt.millisecond, 0);
      });
    });
  });
}
