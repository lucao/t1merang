import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/permission_model.dart';
import 'package:activity_tracker/domain/entities/permission.dart';

void main() {
  group('PermissionModel', () {
    test('fromFirestore creates model from Firestore data', () {
      final data = <String, dynamic>{
        'targetType': 'user',
        'targetId': 'user-1',
        'permissions': ['View', 'Create', 'Modify', 'Move'],
      };

      final model = PermissionModel.fromFirestore(data, 'perm-1');

      expect(model.id, 'perm-1');
      expect(model.targetType, 'user');
      expect(model.targetId, 'user-1');
      expect(model.permissions, ['View', 'Create', 'Modify', 'Move']);
    });

    test('fromFirestore handles sector-level permission', () {
      final data = <String, dynamic>{
        'targetType': 'sector',
        'targetId': 'sector-1',
        'permissions': ['View'],
      };

      final model = PermissionModel.fromFirestore(data, 'perm-2');

      expect(model.targetType, 'sector');
      expect(model.targetId, 'sector-1');
      expect(model.permissions, ['View']);
    });

    test('toFirestore serializes model correctly', () {
      final model = PermissionModel(
        id: 'perm-1',
        targetType: 'user',
        targetId: 'user-1',
        permissions: ['View', 'Create'],
      );

      final data = model.toFirestore();

      expect(data['targetType'], 'user');
      expect(data['targetId'], 'user-1');
      expect(data['permissions'], ['View', 'Create']);
      expect(data.containsKey('id'), false);
    });

    test('toDomain converts permission strings to Permission enum set', () {
      final model = PermissionModel(
        id: 'perm-1',
        targetType: 'user',
        targetId: 'user-1',
        permissions: ['View', 'Create', 'Modify', 'Move'],
      );

      final permissionSet = model.toDomain();

      expect(permissionSet, {
        Permission.view,
        Permission.create,
        Permission.modify,
        Permission.move,
      });
    });

    test('toDomain handles partial permissions', () {
      final model = PermissionModel(
        id: 'perm-1',
        targetType: 'sector',
        targetId: 'sector-1',
        permissions: ['View', 'Move'],
      );

      final permissionSet = model.toDomain();

      expect(permissionSet, {Permission.view, Permission.move});
      expect(permissionSet.contains(Permission.create), false);
      expect(permissionSet.contains(Permission.modify), false);
    });

    test('fromDomain creates model from Permission enum set', () {
      final model = PermissionModel.fromDomain(
        id: 'perm-1',
        targetType: 'user',
        targetId: 'user-1',
        permissionSet: {Permission.view, Permission.create},
      );

      expect(model.id, 'perm-1');
      expect(model.targetType, 'user');
      expect(model.targetId, 'user-1');
      expect(model.permissions.toSet(), {'View', 'Create'});
    });

    test('round-trip preserves permission set', () {
      final originalPermissions = {
        Permission.view,
        Permission.create,
        Permission.modify,
      };

      final model = PermissionModel.fromDomain(
        id: 'perm-1',
        targetType: 'user',
        targetId: 'user-1',
        permissionSet: originalPermissions,
      );
      final firestoreData = model.toFirestore();
      final restored = PermissionModel.fromFirestore(firestoreData, 'perm-1');
      final result = restored.toDomain();

      expect(result, originalPermissions);
    });
  });
}
