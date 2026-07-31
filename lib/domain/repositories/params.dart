import 'package:equatable/equatable.dart';

import '../entities/permission.dart';
import '../entities/post_category.dart';
import '../entities/sort_order.dart';

/// Parameters for creating a new activity.
class CreateActivityParams extends Equatable {
  final String title;
  final String sectorId;
  final String createdBy;

  const CreateActivityParams({
    required this.title,
    required this.sectorId,
    required this.createdBy,
  });

  @override
  List<Object?> get props => [title, sectorId, createdBy];
}

/// Parameters for updating an existing activity.
class UpdateActivityParams extends Equatable {
  final String? title;
  final String modifiedBy;

  const UpdateActivityParams({
    this.title,
    required this.modifiedBy,
  });

  @override
  List<Object?> get props => [title, modifiedBy];
}

/// Parameters for creating a new Kanban state.
class CreateStateParams extends Equatable {
  final String name;
  final int order;
  final SortOrder sortOrder;
  final bool isDefault;
  final int? productionThresholdDays;

  const CreateStateParams({
    required this.name,
    required this.order,
    required this.sortOrder,
    this.isDefault = false,
    this.productionThresholdDays,
  });

  @override
  List<Object?> get props => [
        name,
        order,
        sortOrder,
        isDefault,
        productionThresholdDays,
      ];
}

/// Parameters for creating a new discussion post.
class CreatePostParams extends Equatable {
  final String content;
  final PostCategory category;
  final String authorId;
  final List<String>? targetSectors;

  const CreatePostParams({
    required this.content,
    required this.category,
    required this.authorId,
    this.targetSectors,
  });

  @override
  List<Object?> get props => [content, category, authorId, targetSectors];
}

/// Parameters for updating a user profile.
class UpdateProfileParams extends Equatable {
  final String userId;
  final String? email;
  final String? nickname;
  final String? sectorId;

  const UpdateProfileParams({
    required this.userId,
    this.email,
    this.nickname,
    this.sectorId,
  });

  @override
  List<Object?> get props => [userId, email, nickname, sectorId];
}

/// Represents a permission grant to a user or sector.
class PermissionGrant extends Equatable {
  final String targetType; // "user" or "sector"
  final String targetId;
  final Set<Permission> permissions;

  const PermissionGrant({
    required this.targetType,
    required this.targetId,
    required this.permissions,
  });

  @override
  List<Object?> get props => [targetType, targetId, permissions];
}
