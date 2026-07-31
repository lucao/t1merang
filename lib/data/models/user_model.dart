import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';

/// Firestore DTO for the UserProfile entity.
/// Maps to/from `/users/{userId}` documents.
class UserModel {
  final String id;
  final String email;
  final String nickname;
  final String sectorId;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.nickname,
    required this.sectorId,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] as String,
      nickname: data['nickname'] as String,
      sectorId: data['sectorId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate().toUtc(),
    );
  }

  factory UserModel.fromDomain(UserProfile entity, {DateTime? createdAt}) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      nickname: entity.nickname,
      sectorId: entity.sectorId,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'nickname': nickname,
      'sectorId': sectorId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      email: email,
      nickname: nickname,
      sectorId: sectorId,
    );
  }
}
