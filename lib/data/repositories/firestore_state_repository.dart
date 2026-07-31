import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/activity_tracker_error.dart';
import '../../domain/entities/kanban_state.dart';
import '../../domain/entities/sort_order.dart';
import '../../domain/repositories/params.dart';
import '../../domain/repositories/state_repository.dart';
import '../models/state_model.dart';

/// Firestore implementation of [StateRepository].
///
/// Manages Kanban workflow states stored in the `/states/{stateId}` collection.
/// Enforces a maximum of 10 states and seeds default states on first run.
class FirestoreStateRepository implements StateRepository {
  final FirebaseFirestore _firestore;

  /// Maximum number of states allowed per board.
  static const int maxStates = 10;

  /// Default states seeded on first run.
  static const List<Map<String, dynamic>> _defaultStates = [
    {
      'name': 'Backlog',
      'order': 0,
      'sortOrder': 'oldest_first',
      'isDefault': true,
    },
    {
      'name': 'Development',
      'order': 1,
      'sortOrder': 'newest_first',
      'isDefault': true,
    },
    {
      'name': 'Production',
      'order': 2,
      'sortOrder': 'newest_first',
      'isDefault': true,
      'productionThresholdDays': 30,
    },
  ];

  FirestoreStateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _statesCollection =>
      _firestore.collection('states');

  @override
  Stream<List<KanbanState>> watchStates() {
    return _statesCollection
        .orderBy('order')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        await _seedDefaultStates();
        // Return the default states immediately so the stream emits them
        // The next snapshot from Firestore will contain the seeded data
        return _buildDefaultKanbanStates();
      }
      return snapshot.docs.map((doc) {
        final model = StateModel.fromFirestore(doc.data(), doc.id);
        return model.toDomain();
      }).toList();
    });
  }

  @override
  Future<KanbanState> createState(CreateStateParams params) async {
    // Check current state count to enforce max 10 limit
    final snapshot = await _statesCollection.get();
    if (snapshot.docs.length >= maxStates) {
      throw ActivityTrackerError.stateLimitReached;
    }

    final model = StateModel.fromDomain(
      KanbanState(
        id: '', // Firestore will generate the ID
        name: params.name,
        order: params.order,
        sortOrder: params.sortOrder,
        isDefault: params.isDefault,
        productionThresholdDays: params.productionThresholdDays,
      ),
    );

    final docRef = await _statesCollection.add(model.toFirestore());

    return KanbanState(
      id: docRef.id,
      name: params.name,
      order: params.order,
      sortOrder: params.sortOrder,
      isDefault: params.isDefault,
      productionThresholdDays: params.productionThresholdDays,
    );
  }

  @override
  Future<void> deleteState(String stateId) async {
    await _statesCollection.doc(stateId).delete();
  }

  /// Seeds the default states (Backlog, Development, Production) on first run.
  Future<void> _seedDefaultStates() async {
    final batch = _firestore.batch();

    for (final stateData in _defaultStates) {
      final docRef = _statesCollection.doc();
      batch.set(docRef, stateData);
    }

    await batch.commit();
  }

  /// Builds default KanbanState objects for immediate return during seeding.
  List<KanbanState> _buildDefaultKanbanStates() {
    return [
      const KanbanState(
        id: '',
        name: 'Backlog',
        order: 0,
        sortOrder: SortOrder.oldestFirst,
        isDefault: true,
      ),
      const KanbanState(
        id: '',
        name: 'Development',
        order: 1,
        sortOrder: SortOrder.newestFirst,
        isDefault: true,
      ),
      const KanbanState(
        id: '',
        name: 'Production',
        order: 2,
        sortOrder: SortOrder.newestFirst,
        isDefault: true,
        productionThresholdDays: 30,
      ),
    ];
  }
}
