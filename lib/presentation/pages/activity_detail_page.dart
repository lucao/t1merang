import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/timeline_entry.dart';
import '../blocs/activity/activity_bloc.dart';

/// Displays detailed information about a single activity with tabs
/// for Discussion, Timeline, and Details (responsible users).
///
/// Requirements: 2.1, 2.2, 2.4, 5.2, 5.4, 8.5, 8.6, 13.10
class ActivityDetailPage extends StatefulWidget {
  final String activityId;
  final String currentUserId;
  final String currentSectorId;

  const ActivityDetailPage({
    super.key,
    required this.activityId,
    required this.currentUserId,
    required this.currentSectorId,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleController;
  final _titleFormKey = GlobalKey<FormState>();
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityBloc, ActivityState>(
      builder: (context, state) {
        if (state is ActivityLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ActivityError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: Center(
              child: Text(
                'Error: ${state.message}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (state is ActivityLoaded) {
          return _buildLoadedView(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadedView(BuildContext context, ActivityLoaded state) {
    final activity = state.activity;

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(activity),
        actions: [
          if (activity.isConflicted)
            Tooltip(
              message: 'This activity has a pending conflict',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Discussion'),
            Tab(text: 'Timeline'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Conflict banner (Req 13.10)
          if (activity.isConflicted) _buildConflictBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DiscussionTab(posts: state.posts),
                _TimelineTab(timeline: state.timeline),
                _DetailsTab(
                  activity: activity,
                  currentUserId: widget.currentUserId,
                  onWithdraw: (userId) {
                    context.read<ActivityBloc>().add(
                          WithdrawResponsibility(
                            activityId: activity.id,
                            userId: userId,
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(Activity activity) {
    if (_isEditingTitle) {
      return Form(
        key: _titleFormKey,
        child: TextFormField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Activity title',
          ),
          style: Theme.of(context).textTheme.titleLarge,
          validator: _validateTitle,
          onFieldSubmitted: (_) => _submitTitle(activity),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!activity.isConflicted) {
          setState(() {
            _isEditingTitle = true;
            _titleController.text = activity.title;
          });
        }
      },
      child: Text(
        activity.title,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.length > 200) {
      return 'Title must be 200 characters or less';
    }
    return null;
  }

  void _submitTitle(Activity activity) {
    if (_titleFormKey.currentState?.validate() ?? false) {
      context.read<ActivityBloc>().add(
            UpdateTitle(
              activityId: activity.id,
              newTitle: _titleController.text.trim(),
              userId: widget.currentUserId,
              sectorId: widget.currentSectorId,
            ),
          );
      setState(() {
        _isEditingTitle = false;
      });
    }
  }

  Widget _buildConflictBanner() {
    return MaterialBanner(
      backgroundColor: Colors.orange.shade50,
      leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
      content: const Text(
        'This activity has conflicting changes pending resolution. '
        'Modifications are locked until the conflict is resolved.',
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}

// ---------- Discussion Tab ----------

class _DiscussionTab extends StatelessWidget {
  final List<Post> posts;

  const _DiscussionTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet. Start a discussion!'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final post = posts[index];
        return _PostTile(post: post);
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;

  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${post.authorId} • ${_formatDate(post.createdAt)}',
      ),
      leading: _categoryBadge(post.category),
    );
  }

  Widget _categoryBadge(dynamic category) {
    final label = category.toString().split('.').last;
    final color = switch (label) {
      'information' => Colors.blue,
      'complaint' => Colors.red,
      'askHelp' => Colors.green,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

// ---------- Timeline Tab ----------

class _TimelineTab extends StatelessWidget {
  final List<TimelineEntry> timeline;

  const _TimelineTab({required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const Center(
        child: Text('No timeline entries yet.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final entry = timeline[index];
        return _TimelineEntryTile(entry: entry);
      },
    );
  }
}

class _TimelineEntryTile extends StatelessWidget {
  final TimelineEntry entry;

  const _TimelineEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(entry.durationMinutes);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('${entry.fromStateId} → ${entry.toStateId}'),
        subtitle: Text(
          'By ${entry.transitionedBy} • Duration: $duration',
        ),
        trailing: Text(
          _formatDate(entry.transitionedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

// ---------- Details Tab ----------

class _DetailsTab extends StatelessWidget {
  final Activity activity;
  final String currentUserId;
  final void Function(String userId) onWithdraw;

  const _DetailsTab({
    required this.activity,
    required this.currentUserId,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Responsible Users',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activity.responsibleUsers.map((userId) {
              final isCurrentUser = userId == currentUserId;
              return Chip(
                label: Text(userId),
                deleteIcon: isCurrentUser
                    ? const Icon(Icons.close, size: 18)
                    : null,
                onDeleted: isCurrentUser ? () => onWithdraw(userId) : null,
                avatar: const Icon(Icons.person, size: 18),
              );
            }).toList(),
          ),
          if (activity.responsibleUsers.length <= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'At least one responsible user is required.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          const Spacer(),
          _buildActivityInfo(context),
        ],
      ),
    );
  }

  Widget _buildActivityInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('State', activity.currentStateId),
            _infoRow('Sector', activity.sectorId),
            _infoRow('Version', activity.version.toString()),
            _infoRow(
              'Conflicted',
              activity.isConflicted ? 'Yes' : 'No',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
