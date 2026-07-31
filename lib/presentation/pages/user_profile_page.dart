import 'package:flutter/material.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/entities/user_profile.dart';

/// Displays a user's profile information including their responsible activities,
/// authored posts, and state transitions performed.
///
/// Requirements: 7.3, 7.4, 7.5
class UserProfilePage extends StatefulWidget {
  final UserProfile profile;
  final List<Activity> responsibleActivities;
  final List<Post> authoredPosts;
  final List<TimelineEntry> performedTransitions;

  const UserProfilePage({
    super.key,
    required this.profile,
    required this.responsibleActivities,
    required this.authoredPosts,
    required this.performedTransitions,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.nickname),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Posts'),
            Tab(text: 'Transitions'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProfileHeader(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActivitiesTab(activities: widget.responsibleActivities),
                _PostsTab(posts: widget.authoredPosts),
                _TransitionsTab(transitions: widget.performedTransitions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              child: Text(
                widget.profile.nickname.isNotEmpty
                    ? widget.profile.nickname[0].toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.nickname,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(widget.profile.sectorId),
                    avatar: const Icon(Icons.business, size: 16),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Activities Tab ----------

/// Displays activities the user is responsible for, ordered by most recent
/// state transition date first (Req 7.3).
class _ActivitiesTab extends StatelessWidget {
  final List<Activity> activities;

  const _ActivitiesTab({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Center(
        child: Text('No responsible activities.'),
      );
    }

    // Sort by most recent state transition (stateEnteredAt) descending
    final sorted = List<Activity>.from(activities)
      ..sort((a, b) => b.stateEnteredAt.compareTo(a.stateEnteredAt));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final activity = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.assignment),
            title: Text(
              activity.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'State: ${activity.currentStateId} • '
              '${_formatDate(activity.stateEnteredAt)}',
            ),
            trailing: activity.isConflicted
                ? Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700)
                : null,
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

// ---------- Posts Tab ----------

/// Displays posts authored by the user, ordered by creation date
/// descending (Req 7.4).
class _PostsTab extends StatelessWidget {
  final List<Post> posts;

  const _PostsTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts authored.'),
      );
    }

    // Sort by creation date descending
    final sorted = List<Post>.from(posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final post = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _categoryBadge(post.category),
            title: Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatDate(post.createdAt)),
          ),
        );
      },
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

    return CircleAvatar(
      backgroundColor: color,
      radius: 16,
      child: Text(
        label[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

// ---------- Transitions Tab ----------

/// Displays state transitions performed by the user, ordered by
/// transition date descending (Req 7.5).
class _TransitionsTab extends StatelessWidget {
  final List<TimelineEntry> transitions;

  const _TransitionsTab({required this.transitions});

  @override
  Widget build(BuildContext context) {
    if (transitions.isEmpty) {
      return const Center(
        child: Text('No transitions performed.'),
      );
    }

    // Sort by transition date descending
    final sorted = List<TimelineEntry>.from(transitions)
      ..sort((a, b) => b.transitionedAt.compareTo(a.transitionedAt));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text('${entry.fromStateId} → ${entry.toStateId}'),
            subtitle: Text(
              '${_formatDate(entry.transitionedAt)} • '
              'Duration: ${_formatDuration(entry.durationMinutes)}',
            ),
          ),
        );
      },
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
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
