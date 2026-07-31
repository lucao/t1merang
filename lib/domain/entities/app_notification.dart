import 'package:equatable/equatable.dart';

/// An in-app alert sent to relevant users when a state change or
/// update occurs.
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String activityId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.activityId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        activityId,
        title,
        body,
        read,
        createdAt,
      ];
}
