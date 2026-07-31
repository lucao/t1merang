import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/entities/timeline_entry.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/notification_repository.dart';
import 'package:activity_tracker/domain/use_cases/move_activity_use_case.dart';

/// Feature: activity-tracker
/// Property 5: State transition updates current state
/// Property 6: Mover auto-assignment to responsibility list
/// Property 7: No duplicate entries in responsibility list
///
/// **Validates: Requirements 3.1, 3.3, 8.2, 8.3**

// ─── Mocks ──────────────────────────────────────────────────────────────────

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

  final random = Random(42); // Fixed seed for reproducibility

  setUpAll(() {
    registerFallbackValue(FakeTimelineEntry());
  });

  setUp(() {
    mockActivityRepo = MockActivityRepository();
    mockAccessControlRepo = MockAccessControlRepository();
    mockNotificationRepo = MockNotificationRepository();
  });

  // ─── Generators ─────────────────────────────────────────────────────────

  /// Generates a random alphanumeric string of given length.
  String randomId([int length = 10]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a random state ID distinct from [exclude].
  String randomStateIdExcluding(String exclude) {
    String id;
    do {
      id = 'state_${randomId(6)}';
    } while (id == exclude);
    return id;
  }

  /// Generates a random list of responsible user IDs (0 to 19 users).
  List<String> generateResponsibleUsers({int? count}) {
    final size = count ?? random.nextInt(19); // 0 to 18
    return List.generate(size, (_) => 'user_${randomId(6)}');
  }

  /// Generates a random Activity with given state and responsible users.
  Activity generateActivity({
    String? currentStateId,
    List<String>? responsibleUsers,
    String? sectorId,
  }) {
    final stateId = currentStateId ?? 'state_${randomId(6)}';
    final sector = sectorId ?? 'sector_${randomId(4)}';
    final users = responsibleUsers ?? generateResponsibleUsers(count: random.nextInt(5) + 1);
    final now = DateTime.now().toUtc();
    final enteredAt =
        now.subtract(Duration(minutes: random.nextInt(10000) + 1));

    return Activity(
      id: 'activity_${randomId(8)}',
      title: 'Activity ${randomId(5)}',
      currentStateId: stateId,
      sectorId: sector,
      createdAt: enteredAt.subtract(const Duration(days: 1)),
      createdBy: users.isNotEmpty ? users.first : 'user_creator',
      lastModifiedAt: enteredAt,
      lastModifiedBy: users.isNotEmpty ? users.first : 'user_creator',
      stateEnteredAt: enteredAt,
      responsibleUsers: users,
      isConflicted: false,
      version: 1,
    );
  }

  /// Sets up mocks so the move use case succeeds with Move permission.
  void setupSuccessfulMove(Activity activity) {
    when(() => mockActivityRepo.getActivity(activity.id))
        .thenAnswer((_) async => activity);

    when(() => mockAccessControlRepo.getEffectivePermissions(
          any(),
          activity.sectorId,
        )).thenAnswer((_) async => {Permission.view, Permission.move});

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
  }

  // ─── Property 5: State transition updates current state ───────────────────
  //
  // *For any* activity in state A and any valid target state B (A ≠ B),
  // after a move operation, the activity's currentStateId SHALL equal B.
  //
  // **Validates: Requirements 3.1**

  group(
    'Feature: activity-tracker, Property 5: State transition updates current state',
    () {
      test(
        'for any activity in state A and target state B (A ≠ B), '
        'after move, the result toStateId equals B',
        () async {
          // **Validates: Requirements 3.1**
          for (var i = 0; i < 120; i++) {
            // Reset mocks for each iteration
            reset(mockActivityRepo);
            reset(mockAccessControlRepo);
            reset(mockNotificationRepo);

            // Generate random state A
            final stateA = 'state_${randomId(6)}';
            // Generate random state B ≠ A
            final stateB = randomStateIdExcluding(stateA);
            final mover = 'user_${randomId(6)}';

            // Generate activity in state A
            final activity = generateActivity(
              currentStateId: stateA,
              responsibleUsers: [mover], // mover already in list
            );

            setupSuccessfulMove(activity);

            final fixedNow = DateTime.now().toUtc();
            final useCase = MoveActivityUseCase(
              activityRepository: mockActivityRepo,
              accessControlRepository: mockAccessControlRepo,
              notificationRepository: mockNotificationRepo,
              clock: () => fixedNow,
            );

            final result = await useCase.execute(MoveActivityParams(
              activityId: activity.id,
              targetStateId: stateB,
              movedBy: mover,
            ));

            // Property assertion: after move, toStateId equals target state B
            expect(
              result.toStateId,
              equals(stateB),
              reason:
                  'After moving from $stateA to $stateB, result.toStateId should equal $stateB (iteration $i)',
            );

            // Additionally verify fromStateId was the original state A
            expect(
              result.fromStateId,
              equals(stateA),
              reason:
                  'result.fromStateId should equal original state $stateA (iteration $i)',
            );

            // Verify moveActivity was called with the target state
            verify(() => mockActivityRepo.moveActivity(
                  activity.id,
                  stateB,
                  stateEnteredAt: any(named: 'stateEnteredAt'),
                  responsibleUsers: any(named: 'responsibleUsers'),
                  movedBy: mover,
                )).called(1);
          }
        },
      );
    },
  );

  // ─── Property 6: Mover auto-assignment to responsibility list ─────────────
  //
  // *For any* user who moves an activity and is not already in
  // responsibleUsers, after the move, that user appears in responsibleUsers.
  //
  // **Validates: Requirements 3.3, 8.2**

  group(
    'Feature: activity-tracker, Property 6: Mover auto-assignment to responsibility list',
    () {
      test(
        'for any user not in responsibleUsers who moves the activity, '
        'after move, that user appears in responsibleUsers',
        () async {
          // **Validates: Requirements 3.3, 8.2**
          for (var i = 0; i < 120; i++) {
            reset(mockActivityRepo);
            reset(mockAccessControlRepo);
            reset(mockNotificationRepo);

            // Generate a mover who is NOT in the existing responsible users
            final mover = 'mover_${randomId(8)}';
            final existingUsers = generateResponsibleUsers(
              count: random.nextInt(18) + 1, // 1 to 18 users
            );

            // Ensure mover is not already in the list
            final filteredUsers =
                existingUsers.where((u) => u != mover).toList();
            // Guarantee at least one existing user
            if (filteredUsers.isEmpty) {
              filteredUsers.add('user_existing_${randomId(4)}');
            }

            final activity = generateActivity(
              responsibleUsers: filteredUsers,
            );

            setupSuccessfulMove(activity);

            final fixedNow = DateTime.now().toUtc();
            final useCase = MoveActivityUseCase(
              activityRepository: mockActivityRepo,
              accessControlRepository: mockAccessControlRepo,
              notificationRepository: mockNotificationRepo,
              clock: () => fixedNow,
            );

            final result = await useCase.execute(MoveActivityParams(
              activityId: activity.id,
              targetStateId: randomStateIdExcluding(activity.currentStateId),
              movedBy: mover,
            ));

            // Property assertion: mover now appears in responsibleUsers
            expect(
              result.responsibleUsers.contains(mover),
              isTrue,
              reason:
                  'After move by $mover (not previously in list), mover should appear in responsibleUsers (iteration $i)',
            );

            // Also verify the existing users are still there
            for (final existingUser in filteredUsers) {
              expect(
                result.responsibleUsers.contains(existingUser),
                isTrue,
                reason:
                    'Existing user $existingUser should still be in responsibleUsers (iteration $i)',
              );
            }
          }
        },
      );
    },
  );

  // ─── Property 7: No duplicate entries in responsibility list ──────────────
  //
  // *For any* user who moves an activity and is already in responsibleUsers,
  // the list length SHALL remain unchanged (no duplicate created).
  //
  // **Validates: Requirements 8.3**

  group(
    'Feature: activity-tracker, Property 7: No duplicate entries in responsibility list',
    () {
      test(
        'for any user already in responsibleUsers who moves the activity, '
        'list length remains unchanged (no duplicate)',
        () async {
          // **Validates: Requirements 8.3**
          for (var i = 0; i < 120; i++) {
            reset(mockActivityRepo);
            reset(mockAccessControlRepo);
            reset(mockNotificationRepo);

            // Generate responsible users and pick one as the mover
            final otherUsers = generateResponsibleUsers(
              count: random.nextInt(18) + 1, // 1 to 18 others
            );
            final mover = 'mover_${randomId(8)}';
            // Mover IS already in the list
            final responsibleUsers = [...otherUsers, mover];

            final originalLength = responsibleUsers.length;

            final activity = generateActivity(
              responsibleUsers: responsibleUsers,
            );

            setupSuccessfulMove(activity);

            final fixedNow = DateTime.now().toUtc();
            final useCase = MoveActivityUseCase(
              activityRepository: mockActivityRepo,
              accessControlRepository: mockAccessControlRepo,
              notificationRepository: mockNotificationRepo,
              clock: () => fixedNow,
            );

            final result = await useCase.execute(MoveActivityParams(
              activityId: activity.id,
              targetStateId: randomStateIdExcluding(activity.currentStateId),
              movedBy: mover,
            ));

            // Property assertion: list length unchanged (no duplicate)
            expect(
              result.responsibleUsers.length,
              equals(originalLength),
              reason:
                  'When mover is already in responsibleUsers, list length should remain $originalLength (iteration $i)',
            );

            // Verify mover appears exactly once
            final moverCount =
                result.responsibleUsers.where((u) => u == mover).length;
            expect(
              moverCount,
              equals(1),
              reason:
                  'Mover should appear exactly once in responsibleUsers, got $moverCount (iteration $i)',
            );
          }
        },
      );
    },
  );
}
