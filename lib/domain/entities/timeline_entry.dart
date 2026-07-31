import 'package:equatable/equatable.dart';

/// A record of a state transition within an activity's timeline,
/// tracking how long the activity spent in each state.
class TimelineEntry extends Equatable {
  final String id;
  final String fromStateId;
  final String toStateId;
  final DateTime transitionedAt;
  final String transitionedBy;
  final int durationMinutes;

  const TimelineEntry({
    required this.id,
    required this.fromStateId,
    required this.toStateId,
    required this.transitionedAt,
    required this.transitionedBy,
    required this.durationMinutes,
  });

  @override
  List<Object?> get props => [
        id,
        fromStateId,
        toStateId,
        transitionedAt,
        transitionedBy,
        durationMinutes,
      ];
}
