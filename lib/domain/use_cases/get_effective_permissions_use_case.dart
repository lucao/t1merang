import '../entities/activity_tracker_error.dart';
import '../entities/permission.dart';
import '../repositories/access_control_repository.dart';

/// Result type for canRevokePermission check.
class CanRevokeResult {
  final bool allowed;
  final ActivityTrackerError? error;

  const CanRevokeResult.allowed() : allowed = true, error = null;
  const CanRevokeResult.denied(this.error) : allowed = false;
}

/// Use case that resolves a user's effective permissions within a sector.
///
/// Resolution logic:
/// 1. Query user-level permissions first.
/// 2. If user-level permissions exist, return those (user-level takes precedence).
/// 3. Otherwise, fall back to sector-level permissions.
/// 4. If neither exists, return empty set (new users have no permissions by default).
///
/// Also provides a safety check to prevent permission changes that would
/// eliminate the last user holding all four permissions (full admin).
class GetEffectivePermissionsUseCase {
  final AccessControlRepository _repository;

  GetEffectivePermissionsUseCase(this._repository);

  /// Resolves the effective permissions for a user in a given sector.
  ///
  /// User-level permissions take precedence over sector-level permissions.
  /// If no permissions are assigned at either level, returns an empty set.
  Future<Set<Permission>> call(String userId, String sectorId) async {
    // 1. Check user-level permissions
    final userPermissions = await _repository.getUserPermissions(userId);

    // 2. If user-level permissions exist, they take precedence
    if (userPermissions != null) {
      return userPermissions;
    }

    // 3. Fall back to sector-level permissions
    final sectorPermissions = await _repository.getSectorPermissions(sectorId);

    if (sectorPermissions != null) {
      return sectorPermissions;
    }

    // 4. No permissions assigned at any level - new users have no permissions
    return <Permission>{};
  }

  /// Checks whether a permission revocation is safe to perform.
  ///
  /// A revocation is rejected if it would result in zero users holding all
  /// four permissions (View, Create, Modify, Move), which would lock out
  /// administrative capabilities.
  ///
  /// [userId] - The user whose permissions would be affected.
  /// [permissionsAfterRevoke] - The resulting permission set after the revoke.
  Future<CanRevokeResult> canRevokePermission(
    String userId,
    Set<Permission> permissionsAfterRevoke,
  ) async {
    final allPermissions = Permission.values.toSet();

    // If the user will still have all permissions after revocation, it's safe
    if (permissionsAfterRevoke.containsAll(allPermissions)) {
      return const CanRevokeResult.allowed();
    }

    // The user will lose full-admin status. Check if other full-admins exist.
    final fullAdminUserIds = await _repository.getFullAdminUserIds();

    // Check if there are other full-admin users besides this one
    final otherFullAdmins =
        fullAdminUserIds.where((id) => id != userId).toList();

    if (otherFullAdmins.isEmpty) {
      // This would eliminate the last full-admin
      return const CanRevokeResult.denied(
          ActivityTrackerError.adminSafetyViolation);
    }

    return const CanRevokeResult.allowed();
  }
}
