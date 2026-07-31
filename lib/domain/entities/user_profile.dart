import 'package:equatable/equatable.dart';

/// A person with an email, nickname, and sector who interacts with the system.
class UserProfile extends Equatable {
  final String id;
  final String email;
  final String nickname;
  final String sectorId;

  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.sectorId,
  });

  @override
  List<Object?> get props => [id, email, nickname, sectorId];
}
