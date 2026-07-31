import 'package:equatable/equatable.dart';

import 'sort_order.dart';

/// A user-defined column on the Kanban board representing a phase
/// in the workflow (e.g., Backlog, Development, Production).
class KanbanState extends Equatable {
  final String id;
  final String name;
  final int order;
  final SortOrder sortOrder;
  final bool isDefault;
  final int? productionThresholdDays;

  const KanbanState({
    required this.id,
    required this.name,
    required this.order,
    required this.sortOrder,
    required this.isDefault,
    this.productionThresholdDays,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        order,
        sortOrder,
        isDefault,
        productionThresholdDays,
      ];
}
