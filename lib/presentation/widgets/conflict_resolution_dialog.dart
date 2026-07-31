import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conflict.dart';
import '../../domain/entities/conflict_version.dart';
import '../blocs/conflict/conflict_bloc.dart';
import '../blocs/conflict/conflict_event.dart';

/// A dialog that presents conflicting versions side by side and allows
/// responsible users to vote for the version they consider correct.
///
/// Requirements: 13.5, 13.6
class ConflictResolutionDialog extends StatefulWidget {
  final Conflict conflict;
  final String currentUserId;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.currentUserId,
  });

  /// Shows the dialog as a modal bottom sheet or dialog depending on screen size.
  static Future<void> show(
    BuildContext context, {
    required Conflict conflict,
    required String currentUserId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ConflictBloc>(),
        child: ConflictResolutionDialog(
          conflict: conflict,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemainingTime(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final deadline = widget.conflict.votingDeadline;
    final remaining = deadline.difference(now);
    setState(() {
      _remainingTime = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  /// Returns the versionId that the current user voted for, or null.
  String? get _userVotedVersionId =>
      widget.conflict.votes[widget.currentUserId];

  /// Whether the current user has already voted.
  bool get _hasVoted => _userVotedVersionId != null;

  /// Whether the voting window has expired.
  bool get _isExpired => _remainingTime <= Duration.zero;

  /// Total number of votes cast.
  int get _totalVotesCast => widget.conflict.votes.length;

  /// Count votes for a specific version.
  int _voteCountFor(String versionId) {
    return widget.conflict.votes.values
        .where((v) => v == versionId)
        .length;
  }

  /// Format the remaining duration as HH:MM:SS.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format a DateTime for display.
  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.year}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _castVote(String versionId) {
    context.read<ConflictBloc>().add(
          CastVote(
            conflict: widget.conflict,
            userId: widget.currentUserId,
            versionId: versionId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Conflict: ${widget.conflict.fieldPath}',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCountdownSection(theme),
              const SizedBox(height: 16),
              _buildVoteProgressSection(theme),
              const SizedBox(height: 16),
              _buildVersionsSection(theme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildCountdownSection(ThemeData theme) {
    final isUrgent = _remainingTime.inHours < 1 && !_isExpired;

    return Card(
      color: _isExpired
          ? Colors.red.shade50
          : isUrgent
              ? Colors.orange.shade50
              : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isExpired ? Icons.timer_off : Icons.timer,
              color: _isExpired
                  ? Colors.red
                  : isUrgent
                      ? Colors.orange
                      : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              _isExpired
                  ? 'Voting window closed'
                  : 'Time remaining: ${_formatDuration(_remainingTime)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _isExpired
                    ? Colors.red
                    : isUrgent
                        ? Colors.orange
                        : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteProgressSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.how_to_vote, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Votes cast: $_totalVotesCast',
          style: theme.textTheme.bodyLarge,
        ),
        if (_hasVoted) ...[
          const SizedBox(width: 16),
          Chip(
            avatar: const Icon(Icons.check_circle, size: 18),
            label: const Text('You voted'),
            backgroundColor: Colors.green.shade100,
          ),
        ],
      ],
    );
  }

  Widget _buildVersionsSection(ThemeData theme) {
    final versions = widget.conflict.versions;

    if (versions.length == 2) {
      // Side by side for exactly 2 versions
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildVersionCard(versions[0], theme)),
          const SizedBox(width: 12),
          Expanded(child: _buildVersionCard(versions[1], theme)),
        ],
      );
    }

    // Vertical layout for 3+ versions
    return Column(
      children: versions
          .map((version) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildVersionCard(version, theme),
              ))
          .toList(),
    );
  }

  Widget _buildVersionCard(ConflictVersion version, ThemeData theme) {
    final voteCount = _voteCountFor(version.versionId);
    final isUserChoice = _userVotedVersionId == version.versionId;
    final canVote = !_hasVoted && !_isExpired;

    return Card(
      elevation: isUserChoice ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUserChoice
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version value (the conflicting field content)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUserChoice
                    ? theme.colorScheme.primaryContainer
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${version.value}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Author
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Author: ${version.authorId}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Timestamp
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(version.modifiedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Vote count
            Row(
              children: [
                const Icon(Icons.thumb_up_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$voteCount vote${voteCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isUserChoice) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Your choice',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Vote button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canVote ? () => _castVote(version.versionId) : null,
                icon: const Icon(Icons.how_to_vote),
                label: Text(
                  _hasVoted
                      ? (isUserChoice ? 'Voted' : 'Already voted')
                      : _isExpired
                          ? 'Voting closed'
                          : 'Vote for this',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
