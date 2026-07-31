import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/use_cases/withdraw_responsibility_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late MockActivityRepository mockRepo;
  late WithdrawResponsibilityUseCase useCase;

  setUp(() {
    mockRepo = MockActivityRepository();
    useCase = WithdrawResponsibilityUseCase(activityRepository: mockRepo);
  });

  Activity createActivity({
    required List<String> responsibleUsers,
  }) {
    return Activity(
      id: 'activity-1',
      title: 'Test Activity',
      currentStateId: 'state-1',
      sectorId: 'sector-1',
      createdAt: DateTime.utc(2024, 1, 1),
      createdBy: 'user-1',
      lastModifiedAt: DateTime.utc(2024, 1, 1),
      lastModifiedBy: 'user-1',
      stateEnteredAt: DateTime.utc(2024, 1, 1),
      responsibleUsers: responsibleUsers,
      isConflicted: false,
      version: 1,
    );
  }

  group('WithdrawResponsibilityUseCase', () {
    test('removes user from responsibility list when multiple users exist', () async {
      final activity = createActivity(
        responsibleUsers: ['user-1', 'user-2', 'user-3'],
      );

      when(() => mockRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockRepo.withdrawResponsibility('activity-1', 'user-2'))
          .thenAnswer((_) async {});

      final result = await useCase.execute(
        activityId: 'activity-1',
        userId: 'user-2',
      );

      expect(result, isA<WithdrawResponsibilitySuccess>());
      verify(() => mockRepo.withdrawResponsibility('activity-1', 'user-2'))
          .called(1);
    });

    test('blocks withdrawal when user is the last responsible user', () async {
      final activity = createActivity(
        responsibleUsers: ['user-1'],
      );

      when(() => mockRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);

      final result = await useCase.execute(
        activityId: 'activity-1',
        userId: 'user-1',
      );

      expect(result, isA<WithdrawResponsibilityFailure>());
      expect(
        (result as WithdrawResponsibilityFailure).error,
        ActivityTrackerError.withdrawalBlocked,
      );
      verifyNever(() => mockRepo.withdrawResponsibility(any(), any()));
    });

    test('succeeds silently when user is not in the responsible list', () async {
      final activity = createActivity(
        responsibleUsers: ['user-1', 'user-2'],
      );

      when(() => mockRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);

      final result = await useCase.execute(
        activityId: 'activity-1',
        userId: 'user-99',
      );

      expect(result, isA<WithdrawResponsibilitySuccess>());
      verifyNever(() => mockRepo.withdrawResponsibility(any(), any()));
    });

    test('allows withdrawal when exactly two users are responsible', () async {
      final activity = createActivity(
        responsibleUsers: ['user-1', 'user-2'],
      );

      when(() => mockRepo.getActivity('activity-1'))
          .thenAnswer((_) async => activity);
      when(() => mockRepo.withdrawResponsibility('activity-1', 'user-1'))
          .thenAnswer((_) async {});

      final result = await useCase.execute(
        activityId: 'activity-1',
        userId: 'user-1',
      );

      expect(result, isA<WithdrawResponsibilitySuccess>());
      verify(() => mockRepo.withdrawResponsibility('activity-1', 'user-1'))
          .called(1);
    });
  });
}
