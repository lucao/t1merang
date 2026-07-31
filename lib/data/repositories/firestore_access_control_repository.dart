import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/permission.dart';
import '../../domain/repositories/access_control_repository.dart';
import '../../domain/repositories/params.dart';
import '../models/permission_model.dart';

/// Firestore implementation of [AccessControlRepository].
/// Operates on the `/permissions/{permissionId}` collection.
///
/// Permission resolution: user-level permissions take precedence over
/// sector-level permissions. If no user-level grant exists, sector-level
/// permissions are used. If neither exists, the user has no permissions.
class FirestoreAccessControlRepository implements AccessControlRepository {
  final FirebaseFirestore _firestore;

  FirestoreAccessControlRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _permissionsCollection =>
      _firestore.collection('permissions');

  @override
  Future<Set<Permission>> getEffectivePermissions(
      String userId, String sectorId) async {
    // User-level permissions take precedence over sector-level
    final userPermissions = await getUserPermissions(userId);
    if (userPermissions != null) {
      return userPermissions;
    }

    final sectorPermissions = await getSectorPermissions(sectorId);
    if (sectorPermissions != null) {
      return sectorPermissions;
    }

    // No permissions defined for user or sector
    return <Permission>{};
  }

  @override
  Future<Set<Permission>?> getUserPermissions(String userId) async {
    final snapshot = await _permissionsCollection
        .where('targetType', isEqualTo: 'user')
        .where('targetId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    // Merge all user-level permission grants
    final permissions = <Permission>{};
    for (final doc in snapshot.docs) {
      final model = PermissionModel.fromFirestore(doc.data(), doc.id);
      permissions.addAll(model.toDomain());
    }
    return permissions;
  }

  @override
  Future<Set<Permission>?> getSectorPermissions(String sectorId) async {
    final snapshot = await _permissionsCollection
        .where('targetType', isEqualTo: 'sector')
        .where('targetId', isEqualTo: sectorId)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    // Merge all sector-level permission grants
    final permissions = <Permission>{};
    for (final doc in snapshot.docs) {
      final model = PermissionModel.fromFirestore(doc.data(), doc.id);
      permissions.addAll(model.toDomain());
    }
    return permissions;
  }

  @override
  Future<List<String>> getFullAdminUserIds() async {
    // Query all permission documents
    final snapshot = await _permissionsCollection
        .where('targetType', isEqualTo: 'user')
        .get();

    // Group permissions by targetId and find users with all 4 permissions
    final userPermissionsMap = <String, Set<Permission>>{};
    for (final doc in snapshot.docs) {
      final model = PermissionModel.fromFirestore(doc.data(), doc.id);
      userPermissionsMap
          .putIfAbsent(model.targetId, () => <Permission>{})
          .addAll(model.toDomain());
    }

    const fullPermissions = {
      Permission.view,
      Permission.create,
      Permission.modify,
      Permission.move,
    };

    return userPermissionsMap.entries
        .where((entry) => entry.value.containsAll(fullPermissions))
        .map((entry) => entry.key)
        .toList();
  }

  @override
  Future<void> grantPermission(PermissionGrant grant) async {
    final model = PermissionModel.fromDomain(
      id: '', // Firestore will generate the ID
      targetType: grant.targetType,
      targetId: grant.targetId,
      permissionSet: grant.permissions,
    );
    await _permissionsCollection.add(model.toFirestore());
  }

  @override
  Future<void> revokePermission(String grantId) async {
    await _permissionsCollection.doc(grantId).delete();
  }
}
