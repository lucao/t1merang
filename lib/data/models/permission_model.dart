import '../../domain/entities/permission.dart';

/// Firestore DTO for permission documents.
/// Maps to/from `/permissions/{permissionId}` documents.
class PermissionModel {
  final String id;
  final String targetType;
  final String targetId;
  final List<String> permissions;

  const PermissionModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.permissions,
  });

  factory PermissionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PermissionModel(
      id: id,
      targetType: data['targetType'] as String,
      targetId: data['targetId'] as String,
      permissions: List<String>.from(data['permissions'] as List),
    );
  }

  factory PermissionModel.fromDomain({
    required String id,
    required String targetType,
    required String targetId,
    required Set<Permission> permissionSet,
  }) {
    return PermissionModel(
      id: id,
      targetType: targetType,
      targetId: targetId,
      permissions:
          permissionSet.map((p) => _permissionToString(p)).toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'targetType': targetType,
      'targetId': targetId,
      'permissions': permissions,
    };
  }

  Set<Permission> toDomain() {
    return permissions.map((p) => _parsePermission(p)).toSet();
  }

  static Permission _parsePermission(String value) {
    switch (value) {
      case 'View':
        return Permission.view;
      case 'Create':
        return Permission.create;
      case 'Modify':
        return Permission.modify;
      case 'Move':
        return Permission.move;
      default:
        return Permission.view;
    }
  }

  static String _permissionToString(Permission permission) {
    switch (permission) {
      case Permission.view:
        return 'View';
      case Permission.create:
        return 'Create';
      case Permission.modify:
        return 'Modify';
      case Permission.move:
        return 'Move';
    }
  }
}
