import '../entities/activity.dart';
import '../entities/user_profile.dart';
import 'params.dart';

/// Abstract repository for managing user profiles and responsibilities.
abstract class UserRepository {
  /// Retrieves a user profile by their ID.
  Future<UserProfile> getProfile(String userId);

  /// Updates a user's profile information.
  Future<void> updateProfile(UpdateProfileParams params);

  /// Watches activities where the user is listed as responsible.
  Stream<List<Activity>> watchResponsibleActivities(String userId);
}
