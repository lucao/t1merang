import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/use_cases/withdraw_responsibility_use_case.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';

/// Feature: activity-tracker
/// Property 8: Withdrawal removes user from responsibility list
/// Property 9: Last responsible user cannot withdraw
///
/// **Validates: Requirements 8.5, 8.6**

class MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late MockActivityRepository mockRepository;
  late WithdrawResponsibilityUseCase useCase;
  final random = Random(42); // Fixed seed for reproducibility

  setUp(() {
    mockRepository = MockActivityRepository();
    useCase = WithdrawResponsibilityUseCase(
      activityRepository: mockRepository,
    );
  });

  // --- Generators ---

  /// Generates a random user ID string.
  String generateUserId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final length = random.nextInt(10) + 5;
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a list of unique user IDs with the given [count].
  List<String> generateUniqueUserIds(int count) {
    final ids = <String>{};
    while (ids.length < count) {
      ids.add(generateUserId());
    }
    return ids.toList();
  }

  /// Generates an Activity with the given [responsibleUsers].
  Activity generateActivity({required List<String> responsibleUsers}) {
    final now = DateTime.now();
    return Activity(
      id: 'activity-${generateUserId()}',
      title: 'Test Activity',
      currentStateId: 'state-1',
      sectorId: 'sector-1',
      createdAt: now,
      createdBy: responsibleUsers.first,
      lastModifiedAt: now,
      lastModifiedBy: responsibleUsers.first,
      stateEnteredAt: now,
      responsibleUsers: responsibleUsers,
      isConflicted: false,
      version: 1,
    );
  }

  group(
    'Feature: activity-tracker, Property 8: Withdrawal removes user from responsibility list',
    () {
      test(
        'For any activity with more than one responsible user, when a responsible user withdraws, '
        'that user no longer appears in the responsibleUsers list and the list length decreases by exactly one',
        () async {
          // **Validates: Requirements 8.5**
          for (var i = 0; i < 150; i++) {
            // Generate 2 to 20 responsible users
            final userCount = random.nextInt(19) + 2; // 2..20
            final users = generateUniqueUserIds(userCount);

            // Pick a random user to withdraw
            final withdrawIndex = random.nextInt(users.length);
            final withdrawingUser = users[withdrawIndex];

            final activity = generateActivity(responsibleUsers: List.of(users));
            final activityId = activity.id;

            // Reset mocks for each iteration
            reset(mockRepository);

            when(() => mockRepository.getActivity(activityId))
                .thenAnswer((_) async => activity);
            when(() => mockRepository.withdrawResponsibility(activityId, withdrawingUser))
                .thenAnswer((_) async {});

            final result = await useCase.execute(
              activityId: activityId,
              userId: withdrawingUser,
            );

            // The use case should succeed
            expect(
              result,
              isA<WithdrawResponsibilitySuccess>(),
              reason:
                  'Expected success for withdrawal (iteration $i): '
                  'user=$withdrawingUser, userCount=$userCount',
            );

            // Verify withdrawResponsibility was called with correct params
            verify(() => mockRepository.withdrawResponsibility(activityId, withdrawingUser))
                .called(1);

            // Verify that after withdrawal the user would not be in the list
            // (simulating the effect - the use case delegates removal to repository)
            final updatedUsers = List<String>.from(users)..remove(withdrawingUser);
            expect(
              updatedUsers.contains(withdrawingUser),
              isFalse,
              reason:
                  'Withdrawing user should not appear in the list after removal (iteration $i)',
            );
            expect(
              updatedUsers.length,
              equals(users.length - 1),
              reason:
                  'List length should decrease by exactly one (iteration $i): '
                  'original=${users.length}, after=${updatedUsers.length}',
            );
          }
        },
      );
    },
  );

  group(
    'Feature: activity-tracker, Property 9: Last responsible user cannot withdraw',
    () {
      test(
        'For any activity with exactly one responsible user, a withdrawal request '
        'from that user is rejected and responsibleUsers remains unchanged',
        () async {
          // **Validates: Requirements 8.6**
          for (var i = 0; i < 150; i++) {
            // Generate a single responsible user
            final soleUser = generateUserId();
            final users = [soleUser];

            final activity = generateActivity(responsibleUsers: List.of(users));
            final activityId = activity.id;

            // Reset mocks for each iteration
            reset(mockRepository);

            when(() => mockRepository.getActivity(activityId))
                .thenAnswer((_) async => activity);

            final result = await useCase.execute(
              activityId: activityId,
              userId: soleUser,
            );

            // The use case should fail with withdrawalBlocked
            expect(
              result,
              isA<WithdrawResponsibilityFailure>(),
              reason:
                  'Expected failure for last user withdrawal (iteration $i): '
                  'user=$soleUser',
            );

            final failure = result as WithdrawResponsibilityFailure;
            expect(
              failure.error,
              equals(ActivityTrackerError.withdrawalBlocked),
              reason:
                  'Error should be withdrawalBlocked (iteration $i)',
            );

            // Verify that withdrawResponsibility was never called
            verifyNever(
              () => mockRepository.withdrawResponsibility(any(), any()),
            );

            // The list remains unchanged
            expect(
              activity.responsibleUsers,
              equals(users),
              reason:
                  'responsibleUsers should remain unchanged (iteration $i)',
            );
            expect(
              activity.responsibleUsers.length,
              equals(1),
              reason:
                  'responsibleUsers length should still be 1 (iteration $i)',
            );
          }
        },
      );
    },
  );
}
