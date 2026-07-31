import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/notification_repository.dart';
import 'package:activity_tracker/domain/repositories/params.dart';
import 'package:activity_tracker/domain/use_cases/create_activity_use_case.dart';
import 'package:activity_tracker/domain/use_cases/get_effective_permissions_use_case.dart';
import 'package:activity_tracker/domain/use_cases/move_activity_use_case.dart';
import 'package:activity_tracker/domain/use_cases/update_activity_title_use_case.dart';

// --- Mocks ---

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

// --- Generators ---

final _random = Random(42);

String _randomId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final length = _random.nextInt(8) + 4;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
  );
}

String _randomTitle() {
  const chars = 'abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final length = _random.nextInt(100) + 1;
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
  ).trim().isEmpty
      ? 'fallback title'
      : String.fromCharCodes(
          List.generate(
              length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
        );
}

/// Generates a random subset of permissions that does NOT contain [excluded].
Set<Permission> _permissionsWithout(Permission excluded) {
  final available = Permission.values.where((p) => p != excluded).toList();
  final count = _random.nextInt(available.length + 1); // 0 to 3 permissions
  available.shuffle(_random);
  return available.take(count).toSet();
}

/// Generates a random non-empty subset of permissions.
Set<Permission> _randomPermissionSet() {
  final count = _random.nextInt(Permission.values.length) + 1;
  final shuffled = List<Permission>.from(Permission.values)..shuffle(_random);
  return shuffled.take(count).toSet();
}

/// Generates a set of all four permissions.
Set<Permission> _fullPermissions() => Permission.values.toSet();

Activity _createMockActivity({
  String? id,
  String? sectorId,
  List<String>? responsibleUsers,
}) {
  return Activity(
    id: id ?? _randomId(),
    title: 'Test Activity',
    currentStateId: 'state-backlog',
    sectorId: sectorId ?? 'sector-1',
    createdAt: DateTime.now().toUtc(),
    createdBy: 'creator-user',
    lastModifiedAt: DateTime.now().toUtc(),
    lastModifiedBy: 'creator-user',
    stateEnteredAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    responsibleUsers: responsibleUsers ?? ['creator-user'],
    isConflicted: false,
    version: 1,
  );
}

void main() {
  late MockAccessControlRepository mockAccessControlRepo;
  late MockActivityRepository mockActivityRepo;
  late MockNotificationRepository mockNotificationRepo;

  setUp(() {
    mockAccessControlRepo = MockAccessControlRepository();
    mockActivityRepo = MockActivityRepository();
    mockNotificationRepo = MockNotificationRepository();
  });

  group(
    'Feature: activity-tracker, Property 4: Permission enforcement blocks unauthorized actions',
    () {
      /// **Validates: Requirements 2.5, 3.6, 9.3, 11.3, 11.4, 11.5, 11.6**
      ///
      /// For any user whose effective permissions don't include a required
      /// permission type, the corresponding action is denied.

      test(
        'Create action denied when user lacks Create permission',
        () async {
          final createUseCase = CreateActivityUseCase(
            activityRepository: mockActivityRepo,
            accessControlRepository: mockAccessControlRepo,
          );

          for (var i = 0; i < 120; i++) {
            final userId = _randomId();
            final sectorId = _randomId();
            final title = _randomTitle();
            final permissionsWithoutCreate =
                _permissionsWithout(Permission.create);

            when(() => mockAccessControlRepo.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => permissionsWithoutCreate);

            final result = await createUseCase.execute(
              CreateActivityParams(
                title: title,
                sectorId: sectorId,
                createdBy: userId,
              ),
            );

            expect(
              result,
              isA<CreateActivityFailure>(),
              reason:
                  'Expected CreateActivityFailure when user lacks Create permission '
                  '(iteration $i, permissions: $permissionsWithoutCreate)',
            );
            final failure = result as CreateActivityFailure;
            expect(failure.error, equals(ActivityTrackerError.permissionDenied));
          }
        },
      );

      test(
        'Move action denied when user lacks Move permission',
        () async {
          final moveUseCase = MoveActivityUseCase(
            activityRepository: mockActivityRepo,
            accessControlRepository: mockAccessControlRepo,
            notificationRepository: mockNotificationRepo,
          );

          for (var i = 0; i < 120; i++) {
            final userId = _randomId();
            final activityId = _randomId();
            final targetStateId = _randomId();
            final sectorId = _randomId();
            final permissionsWithoutMove = _permissionsWithout(Permission.move);

            final mockActivity = _createMockActivity(
              id: activityId,
              sectorId: sectorId,
            );

            when(() => mockActivityRepo.getActivity(activityId))
                .thenAnswer((_) async => mockActivity);
            when(() => mockAccessControlRepo.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => permissionsWithoutMove);

            expect(
              () => moveUseCase.execute(
                MoveActivityParams(
                  activityId: activityId,
                  targetStateId: targetStateId,
                  movedBy: userId,
                ),
              ),
              throwsA(equals(ActivityTrackerError.permissionDenied)),
              reason:
                  'Expected permissionDenied error when user lacks Move permission '
                  '(iteration $i, permissions: $permissionsWithoutMove)',
            );
          }
        },
      );

      test(
        'Modify action denied when user lacks Modify permission',
        () async {
          final updateTitleUseCase = UpdateActivityTitleUseCase(
            activityRepository: mockActivityRepo,
            accessControlRepository: mockAccessControlRepo,
          );

          for (var i = 0; i < 120; i++) {
            final userId = _randomId();
            final activityId = _randomId();
            final sectorId = _randomId();
            final newTitle = _randomTitle();
            final permissionsWithoutModify =
                _permissionsWithout(Permission.modify);

            when(() => mockAccessControlRepo.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => permissionsWithoutModify);

            final result = await updateTitleUseCase.call(
              activityId: activityId,
              newTitle: newTitle,
              userId: userId,
              sectorId: sectorId,
            );

            expect(
              result,
              isA<UpdateActivityTitleFailure>(),
              reason:
                  'Expected UpdateActivityTitleFailure when user lacks Modify permission '
                  '(iteration $i, permissions: $permissionsWithoutModify)',
            );
            final failure = result as UpdateActivityTitleFailure;
            expect(failure.error, equals(ActivityTrackerError.permissionDenied));
          }
        },
      );

      test(
        'View action denied when user lacks View permission (effective permissions are empty or missing View)',
        () async {
          // Property 4 also validates Requirement 11.3 (View access denial).
          // We test this by verifying GetEffectivePermissions returns a set
          // that does not include View, which the calling layer would check.
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 120; i++) {
            final userId = _randomId();
            final sectorId = _randomId();
            final permissionsWithoutView =
                _permissionsWithout(Permission.view);

            // Simulate user-level permissions that lack View
            when(() => mockAccessControlRepo.getUserPermissions(userId))
                .thenAnswer((_) async => permissionsWithoutView);

            final effectivePermissions =
                await getPermissionsUseCase.call(userId, sectorId);

            expect(
              effectivePermissions.contains(Permission.view),
              isFalse,
              reason:
                  'Expected effective permissions to NOT contain View '
                  '(iteration $i, permissions: $effectivePermissions)',
            );
          }
        },
      );
    },
  );

  group(
    'Feature: activity-tracker, Property 21: User-level permissions take precedence over sector-level',
    () {
      /// **Validates: Requirements 11.2**
      ///
      /// For any user with both user-level and sector-level permissions,
      /// the effective set equals user-level permissions (ignoring sector-level).

      test(
        'effective permissions equal user-level when both user-level and sector-level exist',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 150; i++) {
            final userId = _randomId();
            final sectorId = _randomId();

            // Generate distinct random permission sets for user and sector
            final userPermissions = _randomPermissionSet();
            final sectorPermissions = _randomPermissionSet();

            when(() => mockAccessControlRepo.getUserPermissions(userId))
                .thenAnswer((_) async => userPermissions);
            when(() => mockAccessControlRepo.getSectorPermissions(sectorId))
                .thenAnswer((_) async => sectorPermissions);

            final effectivePermissions =
                await getPermissionsUseCase.call(userId, sectorId);

            expect(
              effectivePermissions,
              equals(userPermissions),
              reason:
                  'Expected effective permissions to equal user-level permissions '
                  '(iteration $i). User: $userPermissions, Sector: $sectorPermissions, '
                  'Got: $effectivePermissions',
            );
          }
        },
      );

      test(
        'effective permissions fall back to sector-level when no user-level exists',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 120; i++) {
            final userId = _randomId();
            final sectorId = _randomId();
            final sectorPermissions = _randomPermissionSet();

            // No user-level permissions (returns null)
            when(() => mockAccessControlRepo.getUserPermissions(userId))
                .thenAnswer((_) async => null);
            when(() => mockAccessControlRepo.getSectorPermissions(sectorId))
                .thenAnswer((_) async => sectorPermissions);

            final effectivePermissions =
                await getPermissionsUseCase.call(userId, sectorId);

            expect(
              effectivePermissions,
              equals(sectorPermissions),
              reason:
                  'Expected effective permissions to equal sector-level permissions '
                  'when no user-level exists (iteration $i). '
                  'Sector: $sectorPermissions, Got: $effectivePermissions',
            );
          }
        },
      );

      test(
        'effective permissions are empty when neither user-level nor sector-level exists',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 100; i++) {
            final userId = _randomId();
            final sectorId = _randomId();

            when(() => mockAccessControlRepo.getUserPermissions(userId))
                .thenAnswer((_) async => null);
            when(() => mockAccessControlRepo.getSectorPermissions(sectorId))
                .thenAnswer((_) async => null);

            final effectivePermissions =
                await getPermissionsUseCase.call(userId, sectorId);

            expect(
              effectivePermissions,
              isEmpty,
              reason:
                  'Expected empty permissions when no grants exist (iteration $i). '
                  'Got: $effectivePermissions',
            );
          }
        },
      );
    },
  );

  group(
    'Feature: activity-tracker, Property 22: Permission revocation rejected when it eliminates last admin',
    () {
      /// **Validates: Requirements 11.7**
      ///
      /// For any permission change that would result in zero users holding
      /// all four permissions, the change is rejected.

      test(
        'revocation rejected when user is the last full admin and resulting permissions are not full',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 150; i++) {
            final userId = _randomId();

            // Generate a permission set that is NOT a full set (missing at least one)
            Set<Permission> permissionsAfterRevoke;
            do {
              final count = _random.nextInt(Permission.values.length); // 0 to 3
              final shuffled = List<Permission>.from(Permission.values)
                ..shuffle(_random);
              permissionsAfterRevoke = shuffled.take(count).toSet();
            } while (
                permissionsAfterRevoke.containsAll(Permission.values.toSet()));

            // This user is the only full admin
            when(() => mockAccessControlRepo.getFullAdminUserIds())
                .thenAnswer((_) async => [userId]);

            final result = await getPermissionsUseCase.canRevokePermission(
              userId,
              permissionsAfterRevoke,
            );

            expect(
              result.allowed,
              isFalse,
              reason:
                  'Expected revocation to be denied when user is last full admin '
                  '(iteration $i). Permissions after revoke: $permissionsAfterRevoke',
            );
            expect(
              result.error,
              equals(ActivityTrackerError.adminSafetyViolation),
            );
          }
        },
      );

      test(
        'revocation allowed when other full admins exist',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 150; i++) {
            final userId = _randomId();
            final otherAdminId = _randomId();

            // Generate a permission set that is NOT a full set
            Set<Permission> permissionsAfterRevoke;
            do {
              final count = _random.nextInt(Permission.values.length); // 0 to 3
              final shuffled = List<Permission>.from(Permission.values)
                ..shuffle(_random);
              permissionsAfterRevoke = shuffled.take(count).toSet();
            } while (
                permissionsAfterRevoke.containsAll(Permission.values.toSet()));

            // Other full admins exist
            when(() => mockAccessControlRepo.getFullAdminUserIds())
                .thenAnswer((_) async => [userId, otherAdminId]);

            final result = await getPermissionsUseCase.canRevokePermission(
              userId,
              permissionsAfterRevoke,
            );

            expect(
              result.allowed,
              isTrue,
              reason:
                  'Expected revocation to be allowed when other full admins exist '
                  '(iteration $i). Other admins: [$otherAdminId]',
            );
          }
        },
      );

      test(
        'revocation allowed when resulting permissions still contain all four',
        () async {
          final getPermissionsUseCase =
              GetEffectivePermissionsUseCase(mockAccessControlRepo);

          for (var i = 0; i < 100; i++) {
            final userId = _randomId();

            // If the user retains all four permissions, revocation is always safe
            final permissionsAfterRevoke = _fullPermissions();

            // Even if user is the only admin, keeping all perms is fine
            when(() => mockAccessControlRepo.getFullAdminUserIds())
                .thenAnswer((_) async => [userId]);

            final result = await getPermissionsUseCase.canRevokePermission(
              userId,
              permissionsAfterRevoke,
            );

            expect(
              result.allowed,
              isTrue,
              reason:
                  'Expected revocation to be allowed when user retains all permissions '
                  '(iteration $i).',
            );
          }
        },
      );
    },
  );
}
