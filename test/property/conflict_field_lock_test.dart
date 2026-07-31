import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/params.dart';
import 'package:activity_tracker/domain/use_cases/update_activity_title_use_case.dart';

/// Feature: activity-tracker
/// Property 25: Conflicted activity fields are locked from modification
///
/// **Validates: Requirements 13.10**
///
/// For any activity with an active conflict (isConflicted = true),
/// modification attempts to the conflicting field are rejected until
/// the conflict is resolved.

// --- Mocks ---

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

class FakeUpdateActivityParams extends Fake implements UpdateActivityParams {}

void main() {
  late MockActivityRepository mockActivityRepository;
  late MockAccessControlRepository mockAccessControlRepository;
  late UpdateActivityTitleUseCase useCase;

  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random alphanumeric string of [length].
  String _randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a random valid title (1-200 non-whitespace characters).
  String generateValidTitle() {
    final length = random.nextInt(200) + 1;
    return _randomString(length);
  }

  /// Generates a random activity ID.
  String generateActivityId() {
    return 'activity-${_randomString(12)}';
  }

  /// Generates a random user ID.
  String generateUserId() {
    return 'user-${_randomString(8)}';
  }

  /// Generates a random sector ID.
  String generateSectorId() {
    return 'sector-${_randomString(6)}';
  }

  /// Creates a conflicted activity (isConflicted = true) with random fields.
  Activity generateConflictedActivity({
    required String activityId,
    required String sectorId,
  }) {
    return Activity(
      id: activityId,
      title: _randomString(random.nextInt(100) + 1),
      currentStateId: 'state-${_randomString(4)}',
      sectorId: sectorId,
      createdAt: DateTime.now().subtract(Duration(days: random.nextInt(365))),
      createdBy: generateUserId(),
      lastModifiedAt:
          DateTime.now().subtract(Duration(hours: random.nextInt(48))),
      lastModifiedBy: generateUserId(),
      stateEnteredAt:
          DateTime.now().subtract(Duration(hours: random.nextInt(100))),
      responsibleUsers: List.generate(
        random.nextInt(5) + 1,
        (_) => generateUserId(),
      ),
      isConflicted: true,
      version: random.nextInt(100) + 1,
    );
  }

  setUpAll(() {
    registerFallbackValue(FakeUpdateActivityParams());
  });

  setUp(() {
    mockActivityRepository = MockActivityRepository();
    mockAccessControlRepository = MockAccessControlRepository();
    useCase = UpdateActivityTitleUseCase(
      activityRepository: mockActivityRepository,
      accessControlRepository: mockAccessControlRepository,
    );
  });

  group(
    'Feature: activity-tracker, Property 25: Conflicted activity fields are locked from modification',
    () {
      test(
        'modification attempts on a conflicted activity are always rejected with conflictInProgress',
        () async {
          for (var i = 0; i < 150; i++) {
            final activityId = generateActivityId();
            final userId = generateUserId();
            final sectorId = generateSectorId();
            final newTitle = generateValidTitle();

            // Arrange: permission is granted (Modify permission present)
            when(() => mockAccessControlRepository.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer(
              (_) async => {
                Permission.view,
                Permission.create,
                Permission.modify,
                Permission.move,
              },
            );

            // Arrange: activity is conflicted
            final conflictedActivity = generateConflictedActivity(
              activityId: activityId,
              sectorId: sectorId,
            );
            when(() => mockActivityRepository.getActivity(activityId))
                .thenAnswer((_) async => conflictedActivity);

            // Act
            final result = await useCase(
              activityId: activityId,
              newTitle: newTitle,
              userId: userId,
              sectorId: sectorId,
            );

            // Assert: every attempt is rejected with conflictInProgress
            expect(
              result,
              isA<UpdateActivityTitleFailure>(),
              reason:
                  'Iteration $i: Expected UpdateActivityTitleFailure for conflicted activity '
                  '(activityId=$activityId, title="$newTitle")',
            );

            final failure = result as UpdateActivityTitleFailure;
            expect(
              failure.error,
              equals(ActivityTrackerError.conflictInProgress),
              reason:
                  'Iteration $i: Expected conflictInProgress error but got ${failure.error}',
            );

            // Verify updateActivity was never called (field remains locked)
            verifyNever(
              () => mockActivityRepository.updateActivity(
                any(),
                any(),
              ),
            );

            // Reset mocks for next iteration
            reset(mockActivityRepository);
            reset(mockAccessControlRepository);
          }
        },
      );
    },
  );
}
