import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/kanban_state.dart' as domain;
import '../blocs/kanban/kanban_bloc.dart';
import '../blocs/kanban/kanban_event.dart';
import '../blocs/kanban/kanban_state.dart';

/// The main Kanban board page displaying activities grouped into state columns.
///
/// Features:
/// - Responsive layout: horizontal scroll on mobile, full grid on desktop
/// - Drag-and-drop for activity state transitions
/// - Sector filter dropdown at the top
/// - Empty-state indicator when a sector has no activities
/// - Offline indicator and syncing badge
class KanbanBoardPage extends StatelessWidget {
  /// Available sector IDs for the filter dropdown.
  final List<String> availableSectors;

  /// The current user ID (used for move operations).
  final String currentUserId;

  /// Whether the device is currently offline.
  final bool isOffline;

  /// Whether there are pending writes syncing.
  final bool isSyncing;

  const KanbanBoardPage({
    super.key,
    required this.availableSectors,
    required this.currentUserId,
    this.isOffline = false,
    this.isSyncing = false,
  });

  /// Breakpoint width to switch between mobile (horizontal scroll) and desktop (grid).
  static const double _desktopBreakpoint = 800.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board'),
        actions: [
          if (isSyncing)
            Semantics(
              label: 'Syncing changes',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: _SyncingBadge(),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isOffline) const _OfflineIndicator(),
          _buildSectorFilter(context),
          Expanded(
            child: BlocBuilder<KanbanBloc, KanbanBoardState>(
              builder: (context, state) {
                if (state is KanbanLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state is KanbanError) {
                  return Center(
                    child: Semantics(
                      label: 'Error loading board',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            state.message,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<KanbanBloc>().add(const RefreshBoard());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is KanbanLoaded) {
                  return _buildBoard(context, state);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorFilter(BuildContext context) {
    return BlocBuilder<KanbanBloc, KanbanBoardState>(
      builder: (context, state) {
        final currentSectorId = state is KanbanLoaded ? state.currentSectorId : '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Semantics(
                label: 'Filter by sector',
                child: DropdownButton<String>(
                  value: availableSectors.contains(currentSectorId)
                      ? currentSectorId
                      : null,
                  hint: const Text('Select sector'),
                  items: availableSectors.map((sectorId) {
                    return DropdownMenuItem<String>(
                      value: sectorId,
                      child: Text(sectorId),
                    );
                  }).toList(),
                  onChanged: (sectorId) {
                    if (sectorId != null) {
                      context
                          .read<KanbanBloc>()
                          .add(ChangeFilter(sectorId: sectorId));
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoard(BuildContext context, KanbanLoaded state) {
    final columns = state.states;
    final groupedActivities = state.groupedActivities;

    // Check if no activities at all (empty-state for sector)
    final hasAnyActivities = groupedActivities.values
        .any((activities) => activities.isNotEmpty);

    if (!hasAnyActivities) {
      return Center(
        child: Semantics(
          label: 'No activities in this sector',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No activities in this sector',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an activity to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopGrid(context, columns, groupedActivities);
        } else {
          return _buildMobileScroll(context, columns, groupedActivities);
        }
      },
    );
  }

  Widget _buildDesktopGrid(
    BuildContext context,
    List<domain.KanbanState> columns,
    Map<String, List<Activity>> groupedActivities,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns.map((kanbanState) {
        final activities = groupedActivities[kanbanState.id] ?? [];
        return Expanded(
          child: _KanbanColumn(
            kanbanState: kanbanState,
            activities: activities,
            currentUserId: currentUserId,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileScroll(
    BuildContext context,
    List<domain.KanbanState> columns,
    Map<String, List<Activity>> groupedActivities,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((kanbanState) {
          final activities = groupedActivities[kanbanState.id] ?? [];
          return SizedBox(
            width: 280,
            child: _KanbanColumn(
              kanbanState: kanbanState,
              activities: activities,
              currentUserId: currentUserId,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A single column in the Kanban board representing a workflow state.
class _KanbanColumn extends StatelessWidget {
  final domain.KanbanState kanbanState;
  final List<Activity> activities;
  final String currentUserId;

  const _KanbanColumn({
    required this.kanbanState,
    required this.activities,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Activity>(
      onWillAcceptWithDetails: (details) {
        // Accept if the activity is not already in this state
        return details.data.currentStateId != kanbanState.id;
      },
      onAcceptWithDetails: (details) {
        final activity = details.data;
        context.read<KanbanBloc>().add(
              MoveActivity(
                activityId: activity.id,
                targetStateId: kanbanState.id,
                movedBy: currentUserId,
              ),
            );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Semantics(
          label: '${kanbanState.name} column with ${activities.length} activities',
          child: Container(
            margin: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: isHovering
                  ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
              borderRadius: BorderRadius.circular(8.0),
              border: isHovering
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildColumnHeader(context),
                Expanded(
                  child: activities.isEmpty
                      ? _buildEmptyColumn(context)
                      : _buildActivityList(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kanbanState.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${activities.length}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyColumn(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No activities',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ),
    );
  }

  Widget _buildActivityList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityCard(activity: activity);
      },
    );
  }
}

/// A draggable card representing a single activity on the board.
class _ActivityCard extends StatelessWidget {
  final Activity activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Draggable<Activity>(
      data: activity,
      feedback: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(8.0),
        child: SizedBox(
          width: 250,
          child: _buildCardContent(context, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildCardContent(context),
      ),
      child: _buildCardContent(context),
    );
  }

  Widget _buildCardContent(BuildContext context, {bool isDragging = false}) {
    return Semantics(
      label: 'Activity: ${activity.title}',
      child: Card(
        elevation: isDragging ? 8.0 : 1.0,
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: activity.isConflicted
              ? BorderSide(color: Colors.orange.shade400, width: 2.0)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activity.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (activity.isConflicted) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Conflict',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// An indicator shown when the device is offline.
class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Device is offline',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
        color: Colors.orange.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text(
              'You are offline. Changes will sync when reconnected.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A badge displayed when pending changes are syncing.
class _SyncingBadge extends StatelessWidget {
  const _SyncingBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Syncing',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
