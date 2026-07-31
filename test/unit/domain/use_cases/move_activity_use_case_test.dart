import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/notification_repository.dart';
import 'package:activity_tracker/domain/use_cases/move_activity_use_case.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class FakeTimelineEntry extends Fake implements TimelineEntry {}

void main() {
  late MockActivityRepository mockActivityRepo;
  late MockAccessControlRepository mockAccessControlRepo;
  late MockNotificationRepository mockNotificationRepo;
  late MoveActivityUseCase useCase;
  late DateTime fixedNow;

  setUpAll(() {
    registerFallbackValue(FakeTimelineEntry());
  });

  setUp(() {
    mockActivityRepo = MockActivityRepository();
    mockAccessControlRepo = MockAccessControlRepository();
    mockNotificationRepo = MockNotificationRepository();
    fixedNow = DateTime.utc(2024, 6, 15, 12, 0, 0);

    useCase = MoveActivityUseCase(
      activityRepository: mockActivityRepo,
      accessControlRepository: mockAccessControlRepo,
      notificationRepository: mockNotificationRepo,
      clock: () => fixedNow,
    );
  });

  Activity createTestActivity({
    String id = 'activity-1',
    String currentStateId = 'backlog',
    String sectorId = 'sector-1',
    DateTime? stateEnteredAt,
    List<String> responsibleUsers = const ['user-creator'],
  }) {
    return Activity(
      id: id,
      title: 'Test Activity',
      currentStateId: currentStateId,
      sectorId: sectorId,
      createdAt: DateTime.utc(2024, 6, 1),
      createdBy: 'user-creator',
      lastModifiedAt: DateTime.utc(2024, 6, 1),
      lastModifiedBy: 'user-creator',
      stateEnteredAt: stateEnteredAt ?? DateTime.utc(2024, 6, 15, 10, 30, 0),
      responsibleUsers: responsibleUsers,
      isConflicted: false,
      version: 1,
    );
  }

  group('MoveActivityUseCase', () {
    test('denies move when user lacks Move permission', () async {
      final activity = createTestActivity();

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.view, Permission.create});

      expect(
        () => useCase.execute(const MoveActivityParams(
          activityId: 'activity-1',
          targetStateId: 'development',
          movedBy: 'user-mover',
        )),
        throwsA(ActivityTrackerError.permissionDenied),
      );
    });

    test('moves activity to target state successfully', () async {
      final activity = createTestActivity(
        stateEnteredAt: DateTime.utc(2024, 6, 15, 10, 30, 0),
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationRepo.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

      final result = await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-mover',
      ));

      expect(result.fromStateId, 'backlog');
      expect(result.toStateId, 'development');
      expect(result.transitionedAt, fixedNow);
      // Duration: from 10:30 to 12:00 = 90 minutes
      expect(result.durationMinutes, 90);
    });

    test('adds mover to responsible users if not already present', () async {
      final activity = createTestActivity(
        responsibleUsers: ['user-creator'],
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationRepo.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

      final result = await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-mover',
      ));

      expect(result.responsibleUsers, contains('user-mover'));
      expect(result.responsibleUsers, contains('user-creator'));

      verify(() => mockActivityRepo.moveActivity(
            'activity-1',
            'development',
            stateEnteredAt: fixedNow,
            responsibleUsers: ['user-creator', 'user-mover'],
            movedBy: 'user-mover',
          )).called(1);
    });

    test('does not duplicate mover in responsible users if already present',
        () async {
      final activity = createTestActivity(
        responsibleUsers: ['user-creator', 'user-mover'],
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationRepo.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

      final result = await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-mover',
      ));

      expect(result.responsibleUsers.length, 2);
      expect(
        result.responsibleUsers.where((u) => u == 'user-mover').length,
        1,
      );

      verify(() => mockActivityRepo.moveActivity(
            'activity-1',
            'development',
            stateEnteredAt: fixedNow,
            responsibleUsers: ['user-creator', 'user-mover'],
            movedBy: 'user-mover',
          )).called(1);
    });

    test('records timeline entry with correct duration', () async {
      // stateEnteredAt is 10:30:45, now is 12:00:00
      // duration = 5355 seconds / 60 = 89.25 -> floor = 89 minutes
      final activity = createTestActivity(
        stateEnteredAt: DateTime.utc(2024, 6, 15, 10, 30, 45),
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationRepo.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

      final result = await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-mover',
      ));

      expect(result.durationMinutes, 89);

      final captured = verify(() =>
              mockActivityRepo.addTimelineEntry('activity-1', captureAny()))
          .captured
          .single as TimelineEntry;

      expect(captured.fromStateId, 'backlog');
      expect(captured.toStateId, 'development');
      expect(captured.transitionedAt, fixedNow);
      expect(captured.transitionedBy, 'user-mover');
      expect(captured.durationMinutes, 89);
    });

    test('sends notification to other responsible users, not the mover',
        () async {
      final activity = createTestActivity(
        responsibleUsers: ['user-creator', 'user-other', 'user-mover'],
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationRepo.sendNotification(
            userId: any(named: 'userId'),
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});

      await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-mover',
      ));

      // Should notify user-creator and user-other, but NOT user-mover
      verify(() => mockNotificationRepo.sendNotification(
            userId: 'user-creator',
            type: 'state_change',
            activityId: 'activity-1',
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).called(1);
      verify(() => mockNotificationRepo.sendNotification(
            userId: 'user-other',
            type: 'state_change',
            activityId: 'activity-1',
            title: any(named: 'title'),
            body: any(named: 'body'),
          )).called(1);
      verifyNever(() => mockNotificationRepo.sendNotification(
            userId: 'user-mover',
            type: any(named: 'type'),
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ));
    });

    test('calculates zero duration when moved immediately after entering state',
        () async {
      // stateEnteredAt is exactly now (0 seconds elapsed)
      final activity = createTestActivity(
        stateEnteredAt: fixedNow,
      );

      when(() => mockActivityRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockAccessControlRepo.getEffectivePermissions(
            'user-mover',
            'sector-1',
          )).thenAnswer((_) async => {Permission.move});
      when(() => mockActivityRepo.moveActivity(
            any(),
            any(),
            stateEnteredAt: any(named: 'stateEnteredAt'),
            responsibleUsers: any(named: 'responsibleUsers'),
            movedBy: any(named: 'movedBy'),
          )).thenAnswer((_) async {});
      when(() => mockActivityRepo.addTimelineEntry(any(), any()))
          .thenAnswer((_) async {});

      final result = await useCase.execute(const MoveActivityParams(
        activityId: 'activity-1',
        targetStateId: 'development',
        movedBy: 'user-creator',
      ));

      expect(result.durationMinutes, 0);
    });
  });
}
