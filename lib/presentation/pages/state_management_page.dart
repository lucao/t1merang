import 'package:flutter/material.dart';

import '../../domain/entities/kanban_state.dart';
import '../../domain/entities/sort_order.dart';
import '../../domain/repositories/params.dart';

/// Page for creating custom Kanban states and configuring their sort order.
///
/// Shows a form to create new states (name 1-50 chars, sort order selection)
/// and lists existing states with their configuration.
///
/// Requirements: 4.2, 4.4
class StateManagementPage extends StatefulWidget {
  /// Existing Kanban states to display.
  final List<KanbanState> existingStates;

  /// Callback invoked when a new state is created.
  final void Function(CreateStateParams params)? onCreateState;

  /// Callback invoked when a state is deleted by ID.
  final void Function(String stateId)? onDeleteState;

  const StateManagementPage({
    super.key,
    required this.existingStates,
    this.onCreateState,
    this.onDeleteState,
  });

  @override
  State<StateManagementPage> createState() => _StateManagementPageState();
}

class _StateManagementPageState extends State<StateManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  SortOrder _selectedSortOrder = SortOrder.oldestFirst;
  bool _isDefault = false;
  int? _productionThresholdDays;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('State Management'),
      ),
      body: Column(
        children: [
          _buildCreateForm(context),
          const Divider(height: 1),
          Expanded(child: _buildStateList(context)),
        ],
      ),
    );
  }

  Widget _buildCreateForm(BuildContext context) {
    final hasReachedLimit = widget.existingStates.length >= 10;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New State',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hasReachedLimit) ...[
                const SizedBox(height: 8),
                Text(
                  'Maximum of 10 states reached.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              // State name input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'State Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter state name (1-50 characters)',
                  counterText: '',
                ),
                maxLength: 50,
                enabled: !hasReachedLimit,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'State name is required';
                  }
                  if (value.trim().length > 50) {
                    return 'State name must be 50 characters or less';
                  }
                  // Case-insensitive uniqueness check
                  final lowerName = value.trim().toLowerCase();
                  final exists = widget.existingStates.any(
                    (s) => s.name.toLowerCase() == lowerName,
                  );
                  if (exists) {
                    return 'A state with this name already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Sort order selection
              Row(
                children: [
                  const Text('Sort Order: '),
                  const SizedBox(width: 8),
                  DropdownButton<SortOrder>(
                    value: _selectedSortOrder,
                    items: const [
                      DropdownMenuItem(
                        value: SortOrder.oldestFirst,
                        child: Text('Oldest First'),
                      ),
                      DropdownMenuItem(
                        value: SortOrder.newestFirst,
                        child: Text('Newest First'),
                      ),
                    ],
                    onChanged: hasReachedLimit
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _selectedSortOrder = value;
                              });
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Default state checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default state'),
                value: _isDefault,
                onChanged: hasReachedLimit
                    ? null
                    : (value) {
                        setState(() {
                          _isDefault = value ?? false;
                        });
                      },
              ),
              const SizedBox(height: 16),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasReachedLimit ? null : _submitState,
                  icon: const Icon(Icons.add),
                  label: const Text('Create State'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitState() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final params = CreateStateParams(
      name: _nameController.text.trim(),
      order: widget.existingStates.length,
      sortOrder: _selectedSortOrder,
      isDefault: _isDefault,
      productionThresholdDays: _productionThresholdDays,
    );

    widget.onCreateState?.call(params);

    // Reset form
    _nameController.clear();
    setState(() {
      _selectedSortOrder = SortOrder.oldestFirst;
      _isDefault = false;
      _productionThresholdDays = null;
    });
  }

  Widget _buildStateList(BuildContext context) {
    if (widget.existingStates.isEmpty) {
      return const Center(
        child: Text('No states configured.'),
      );
    }

    // Sort by order
    final sorted = List<KanbanState>.from(widget.existingStates)
      ..sort((a, b) => a.order.compareTo(b.order));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final state = sorted[index];
        return _StateTile(
          kanbanState: state,
          onDelete: state.isDefault
              ? null
              : () => widget.onDeleteState?.call(state.id),
        );
      },
    );
  }
}

/// Displays a single Kanban state with its configuration.
class _StateTile extends StatelessWidget {
  final KanbanState kanbanState;
  final VoidCallback? onDelete;

  const _StateTile({
    required this.kanbanState,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sortLabel = kanbanState.sortOrder == SortOrder.oldestFirst
        ? 'Oldest First'
        : 'Newest First';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${kanbanState.order + 1}'),
        ),
        title: Row(
          children: [
            Text(kanbanState.name),
            if (kanbanState.isDefault) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('Default'),
                labelStyle: TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Sort: $sortLabel'
          '${kanbanState.productionThresholdDays != null ? ' • Threshold: ${kanbanState.productionThresholdDays} days' : ''}',
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete state',
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
