import '../entities/kanban_state.dart';
import 'params.dart';

/// Abstract repository for managing Kanban workflow states.
abstract class StateRepository {
  /// Watches all Kanban states in real-time, ordered by their sequence.
  Stream<List<KanbanState>> watchStates();

  /// Creates a new Kanban state with the given parameters.
  Future<KanbanState> createState(CreateStateParams params);

  /// Deletes a Kanban state by its ID.
  Future<void> deleteState(String stateId);
}
