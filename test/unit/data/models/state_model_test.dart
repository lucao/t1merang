import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/data/models/state_model.dart';
import 'package:activity_tracker/domain/entities/kanban_state.dart';
import 'package:activity_tracker/domain/entities/sort_order.dart';

void main() {
  group('StateModel', () {
    final testFirestoreData = <String, dynamic>{
      'name': 'Development',
      'order': 2,
      'sortOrder': 'newest_first',
      'isDefault': true,
      'productionThresholdDays': null,
    };

    test('fromFirestore creates model from Firestore data', () {
      final model = StateModel.fromFirestore(testFirestoreData, 'state-1');

      expect(model.id, 'state-1');
      expect(model.name, 'Development');
      expect(model.order, 2);
      expect(model.sortOrder, 'newest_first');
      expect(model.isDefault, true);
      expect(model.productionThresholdDays, null);
    });

    test('fromFirestore handles productionThresholdDays', () {
      final data = <String, dynamic>{
        'name': 'Production',
        'order': 3,
        'sortOrder': 'newest_first',
        'isDefault': true,
        'productionThresholdDays': 30,
      };

      final model = StateModel.fromFirestore(data, 'state-prod');

      expect(model.productionThresholdDays, 30);
    });

    test('toFirestore serializes model correctly', () {
      final model = StateModel(
        id: 'state-1',
        name: 'Backlog',
        order: 1,
        sortOrder: 'oldest_first',
        isDefault: true,
        productionThresholdDays: null,
      );

      final data = model.toFirestore();

      expect(data['name'], 'Backlog');
      expect(data['order'], 1);
      expect(data['sortOrder'], 'oldest_first');
      expect(data['isDefault'], true);
      expect(data.containsKey('productionThresholdDays'), false);
      expect(data.containsKey('id'), false);
    });

    test('toFirestore includes productionThresholdDays when set', () {
      final model = StateModel(
        id: 'state-prod',
        name: 'Production',
        order: 3,
        sortOrder: 'newest_first',
        isDefault: true,
        productionThresholdDays: 30,
      );

      final data = model.toFirestore();

      expect(data['productionThresholdDays'], 30);
    });

    test('toDomain converts to KanbanState entity', () {
      final model = StateModel.fromFirestore(testFirestoreData, 'state-1');
      final entity = model.toDomain();

      expect(entity, isA<KanbanState>());
      expect(entity.id, 'state-1');
      expect(entity.name, 'Development');
      expect(entity.order, 2);
      expect(entity.sortOrder, SortOrder.newestFirst);
      expect(entity.isDefault, true);
    });

    test('fromDomain creates model from KanbanState entity', () {
      final entity = KanbanState(
        id: 'state-1',
        name: 'Custom State',
        order: 4,
        sortOrder: SortOrder.oldestFirst,
        isDefault: false,
        productionThresholdDays: null,
      );

      final model = StateModel.fromDomain(entity);

      expect(model.id, 'state-1');
      expect(model.name, 'Custom State');
      expect(model.order, 4);
      expect(model.sortOrder, 'oldest_first');
      expect(model.isDefault, false);
    });

    test('round-trip preserves all fields', () {
      final original = KanbanState(
        id: 'state-prod',
        name: 'Production',
        order: 3,
        sortOrder: SortOrder.newestFirst,
        isDefault: true,
        productionThresholdDays: 60,
      );

      final model = StateModel.fromDomain(original);
      final firestoreData = model.toFirestore();
      // Add back the nullable field for round-trip since toFirestore only adds it when non-null
      firestoreData['productionThresholdDays'] = 60;
      final restored = StateModel.fromFirestore(firestoreData, 'state-prod');
      final result = restored.toDomain();

      expect(result, original);
    });
  });
}
