import 'package:activity_tracker/domain/entities/activity_tracker_error.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/use_cases/get_effective_permissions_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

void main() {
  late MockAccessControlRepository mockRepository;
  late GetEffectivePermissionsUseCase useCase;

  setUp(() {
    mockRepository = MockAccessControlRepository();
    useCase = GetEffectivePermissionsUseCase(mockRepository);
  });

  group('GetEffectivePermissionsUseCase - permission resolution', () {
    test('returns user-level permissions when they exist', () async {
      final userPermissions = {Permission.view, Permission.create};
      when(() => mockRepository.getUserPermissions('user1'))
          .thenAnswer((_) async => userPermissions);

      final result = await useCase('user1', 'sector1');

      expect(result, equals(userPermissions));
      // Should not even query sector permissions
      verifyNever(() => mockRepository.getSectorPermissions(any()));
    });

    test('falls back to sector-level permissions when no user-level exists',
        () async {
      final sectorPermissions = {Permission.view};
      when(() => mockRepository.getUserPermissions('user1'))
          .thenAnswer((_) async => null);
      when(() => mockRepository.getSectorPermissions('sector1'))
          .thenAnswer((_) async => sectorPermissions);

      final result = await useCase('user1', 'sector1');

      expect(result, equals(sectorPermissions));
    });

    test('returns empty set when no permissions exist at any level', () async {
      when(() => mockRepository.getUserPermissions('user1'))
          .thenAnswer((_) async => null);
      when(() => mockRepository.getSectorPermissions('sector1'))
          .thenAnswer((_) async => null);

      final result = await useCase('user1', 'sector1');

      expect(result, isEmpty);
    });

    test('user-level empty set takes precedence over sector-level permissions',
        () async {
      // User explicitly has empty permissions (explicitly assigned no perms)
      when(() => mockRepository.getUserPermissions('user1'))
          .thenAnswer((_) async => <Permission>{});

      final result = await useCase('user1', 'sector1');

      expect(result, isEmpty);
      verifyNever(() => mockRepository.getSectorPermissions(any()));
    });

    test(
        'user-level permissions take precedence even when sector has more permissions',
        () async {
      final userPermissions = {Permission.view};
      when(() => mockRepository.getUserPermissions('user1'))
          .thenAnswer((_) async => userPermissions);

      final result = await useCase('user1', 'sector1');

      expect(result, equals({Permission.view}));
      verifyNever(() => mockRepository.getSectorPermissions(any()));
    });
  });

  group('GetEffectivePermissionsUseCase - canRevokePermission', () {
    test('allows revocation when user retains all permissions', () async {
      final permissionsAfterRevoke = Permission.values.toSet();

      final result =
          await useCase.canRevokePermission('user1', permissionsAfterRevoke);

      expect(result.allowed, isTrue);
      expect(result.error, isNull);
    });

    test('allows revocation when other full-admins exist', () async {
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => ['user1', 'user2']);

      final result = await useCase.canRevokePermission(
          'user1', {Permission.view, Permission.create});

      expect(result.allowed, isTrue);
      expect(result.error, isNull);
    });

    test(
        'denies revocation when it would eliminate the last full-admin',
        () async {
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => ['user1']);

      final result = await useCase.canRevokePermission(
          'user1', {Permission.view, Permission.create});

      expect(result.allowed, isFalse);
      expect(result.error, equals(ActivityTrackerError.adminSafetyViolation));
    });

    test('denies revocation to empty permissions when user is last admin',
        () async {
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => ['user1']);

      final result = await useCase.canRevokePermission('user1', <Permission>{});

      expect(result.allowed, isFalse);
      expect(result.error, equals(ActivityTrackerError.adminSafetyViolation));
    });

    test('allows revocation to empty permissions when other admins exist',
        () async {
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => ['user1', 'admin2', 'admin3']);

      final result = await useCase.canRevokePermission('user1', <Permission>{});

      expect(result.allowed, isTrue);
    });

    test(
        'allows revocation when user was never a full-admin and others exist',
        () async {
      // user2 loses some permission but user1 is still full admin
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => ['user1']);

      final result =
          await useCase.canRevokePermission('user2', {Permission.view});

      expect(result.allowed, isTrue);
    });

    test(
        'denies when no full-admins would remain after revocation',
        () async {
      // No full admins exist at all (edge case)
      when(() => mockRepository.getFullAdminUserIds())
          .thenAnswer((_) async => []);

      final result =
          await useCase.canRevokePermission('user1', {Permission.view});

      // No other admins exist, so this would leave zero admins
      expect(result.allowed, isFalse);
      expect(result.error, equals(ActivityTrackerError.adminSafetyViolation));
    });
  });
}
