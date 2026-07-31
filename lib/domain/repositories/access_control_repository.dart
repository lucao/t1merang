import '../entities/permission.dart';
import 'params.dart';

/// Abstract repository for managing access control and permissions.
abstract class AccessControlRepository {
  /// Retrieves the effective permissions for a user within a sector.
  Future<Set<Permission>> getEffectivePermissions(
      String userId, String sectorId);

  /// Retrieves user-level permissions (grants targeting the specific user).
  /// Returns null if no user-level grant exists.
  Future<Set<Permission>?> getUserPermissions(String userId);

  /// Retrieves sector-level permissions (grants targeting the sector).
  /// Returns null if no sector-level grant exists.
  Future<Set<Permission>?> getSectorPermissions(String sectorId);

  /// Returns all user IDs that currently hold a full set of permissions
  /// (View, Create, Modify, Move).
  Future<List<String>> getFullAdminUserIds();

  /// Grants permissions as defined in the permission grant.
  Future<void> grantPermission(PermissionGrant grant);

  /// Revokes a specific permission grant by its ID.
  Future<void> revokePermission(String grantId);
}
