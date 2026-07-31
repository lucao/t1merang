import 'package:flutter/material.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/post_category.dart';
import '../../domain/repositories/params.dart';

/// A list of available sectors for Ask_Help targeting.
/// In production this would come from a repository; here we use a static list.
const List<String> kAvailableSectors = [
  'Engineering',
  'Design',
  'Marketing',
  'Sales',
  'Support',
  'Finance',
  'HR',
  'Operations',
  'Legal',
  'Product',
];

/// Widget that displays the discussion section for an activity.
///
/// Shows a post creation form at the top, category filter controls,
/// and a scrollable list of posts with category badges and timestamps.
class DiscussionSection extends StatefulWidget {
  final List<Post> posts;
  final Function(CreatePostParams) onCreatePost;
  final PostCategory? categoryFilter;
  final Function(PostCategory?) onFilterChanged;
  final String currentUserId;

  const DiscussionSection({
    super.key,
    required this.posts,
    required this.onCreatePost,
    required this.categoryFilter,
    required this.onFilterChanged,
    required this.currentUserId,
  });

  @override
  State<DiscussionSection> createState() => _DiscussionSectionState();
}

class _DiscussionSectionState extends State<DiscussionSection> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  PostCategory _selectedCategory = PostCategory.information;
  List<String> _selectedSectors = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for Ask_Help sector requirement.
    if (_selectedCategory == PostCategory.askHelp &&
        _selectedSectors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one target sector is required for Ask Help posts.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final params = CreatePostParams(
      content: _contentController.text.trim(),
      category: _selectedCategory,
      authorId: widget.currentUserId,
      targetSectors:
          _selectedCategory == PostCategory.askHelp ? _selectedSectors : null,
    );

    widget.onCreatePost(params);

    // Reset form after submission.
    _contentController.clear();
    setState(() {
      _selectedCategory = PostCategory.information;
      _selectedSectors = [];
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPostCreationForm(context),
        const SizedBox(height: 16),
        _buildCategoryFilter(context),
        const SizedBox(height: 8),
        Expanded(child: _buildPostList(context)),
      ],
    );
  }

  Widget _buildPostCreationForm(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Post',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Post content',
                  hintText: 'Write your message...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 2000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Post content is required';
                  }
                  if (value.trim().length > 2000) {
                    return 'Post content must be 2000 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildCategorySelector(context),
              if (_selectedCategory == PostCategory.askHelp) ...[
                const SizedBox(height: 12),
                _buildSectorMultiSelect(context),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: const Icon(Icons.send),
                  label: const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    return SegmentedButton<PostCategory>(
      segments: const [
        ButtonSegment(
          value: PostCategory.information,
          label: Text('Information'),
          icon: Icon(Icons.info_outline),
        ),
        ButtonSegment(
          value: PostCategory.complaint,
          label: Text('Complaint'),
          icon: Icon(Icons.warning_amber),
        ),
        ButtonSegment(
          value: PostCategory.askHelp,
          label: Text('Ask Help'),
          icon: Icon(Icons.help_outline),
        ),
      ],
      selected: {_selectedCategory},
      onSelectionChanged: (selection) {
        setState(() {
          _selectedCategory = selection.first;
          if (_selectedCategory != PostCategory.askHelp) {
            _selectedSectors = [];
          }
        });
      },
    );
  }

  Widget _buildSectorMultiSelect(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Sectors (select 1–10)',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: kAvailableSectors.map((sector) {
            final isSelected = _selectedSectors.contains(sector);
            return FilterChip(
              label: Text(sector),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (_selectedSectors.length < 10) {
                      _selectedSectors = [..._selectedSectors, sector];
                    }
                  } else {
                    _selectedSectors =
                        _selectedSectors.where((s) => s != sector).toList();
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_selectedSectors.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'At least one sector is required',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return Row(
      children: [
        Text(
          'Filter: ',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 8),
        _buildFilterChip(context, null, 'All'),
        const SizedBox(width: 4),
        _buildFilterChip(context, PostCategory.information, 'Information'),
        const SizedBox(width: 4),
        _buildFilterChip(context, PostCategory.complaint, 'Complaint'),
        const SizedBox(width: 4),
        _buildFilterChip(context, PostCategory.askHelp, 'Ask Help'),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    PostCategory? category,
    String label,
  ) {
    final isSelected = widget.categoryFilter == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => widget.onFilterChanged(category),
    );
  }

  Widget _buildPostList(BuildContext context) {
    if (widget.posts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet. Be the first to contribute!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      itemCount: widget.posts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = widget.posts[index];
        return _PostTile(post: post);
      },
    );
  }
}

/// Displays a single post with category badge, author, timestamp, and content.
class _PostTile extends StatelessWidget {
  final Post post;

  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(category: post.category),
              const SizedBox(width: 8),
              Text(
                post.authorId,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(post.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(post.content, style: theme.textTheme.bodyMedium),
          if (post.targetSectors != null &&
              post.targetSectors!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: post.targetSectors!
                  .map(
                    (sector) => Chip(
                      label: Text(sector),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

/// Colored chip badge showing the post category.
class _CategoryBadge extends StatelessWidget {
  final PostCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (category) {
      PostCategory.information => ('Info', Colors.blue),
      PostCategory.complaint => ('Complaint', Colors.orange),
      PostCategory.askHelp => ('Ask Help', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
