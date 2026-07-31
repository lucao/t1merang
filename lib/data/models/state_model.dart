import '../../domain/entities/kanban_state.dart';
import '../../domain/entities/sort_order.dart';

/// Firestore DTO for the KanbanState entity.
/// Maps to/from `/states/{stateId}` documents.
class StateModel {
  final String id;
  final String name;
  final int order;
  final String sortOrder;
  final bool isDefault;
  final int? productionThresholdDays;

  const StateModel({
    required this.id,
    required this.name,
    required this.order,
    required this.sortOrder,
    required this.isDefault,
    this.productionThresholdDays,
  });

  factory StateModel.fromFirestore(Map<String, dynamic> data, String id) {
    return StateModel(
      id: id,
      name: data['name'] as String,
      order: data['order'] as int,
      sortOrder: data['sortOrder'] as String,
      isDefault: data['isDefault'] as bool,
      productionThresholdDays: data['productionThresholdDays'] as int?,
    );
  }

  factory StateModel.fromDomain(KanbanState entity) {
    return StateModel(
      id: entity.id,
      name: entity.name,
      order: entity.order,
      sortOrder: _sortOrderToString(entity.sortOrder),
      isDefault: entity.isDefault,
      productionThresholdDays: entity.productionThresholdDays,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
      if (productionThresholdDays != null)
        'productionThresholdDays': productionThresholdDays,
    };
  }

  KanbanState toDomain() {
    return KanbanState(
      id: id,
      name: name,
      order: order,
      sortOrder: _parseSortOrder(sortOrder),
      isDefault: isDefault,
      productionThresholdDays: productionThresholdDays,
    );
  }

  static SortOrder _parseSortOrder(String value) {
    switch (value) {
      case 'oldest_first':
        return SortOrder.oldestFirst;
      case 'newest_first':
        return SortOrder.newestFirst;
      default:
        return SortOrder.oldestFirst;
    }
  }

  static String _sortOrderToString(SortOrder sortOrder) {
    switch (sortOrder) {
      case SortOrder.oldestFirst:
        return 'oldest_first';
      case SortOrder.newestFirst:
        return 'newest_first';
    }
  }
}
