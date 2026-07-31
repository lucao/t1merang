import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/post.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/entities/user_profile.dart';
import 'package:activity_tracker/domain/use_cases/resolve_notification_recipients.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ResolveNotificationRecipients resolver;

  setUp(() {
    resolver = ResolveNotificationRecipients();
  });

  Activity createActivity({
    List<String> responsibleUsers = const ['user1', 'user2', 'user3'],
    String title = 'Test Activity',
  }) {
    return Activity(
      id: 'activity1',
      title: title,
      currentStateId: 'state1',
      sectorId: 'sector1',
      createdAt: DateTime.utc(2024, 1, 1),
      createdBy: 'user1',
      lastModifiedAt: DateTime.utc(2024, 1, 1),
      lastModifiedBy: 'user1',
      stateEnteredAt: DateTime.utc(2024, 1, 1),
      responsibleUsers: responsibleUsers,
      isConflicted: false,
      version: 1,
    );
  }

  group('resolveForStateChange', () {
    test('excludes acting user from responsible users', () {
      final activity = createActivity();
      final result = resolver.resolveForStateChange(activity, 'user1');
      expect(result, ['user2', 'user3']);
    });

    test('returns all users when acting user is not responsible', () {
      final activity = createActivity();
      final result = resolver.resolveForStateChange(activity, 'user99');
      expect(result, ['user1', 'user2', 'user3']);
    });

    test('returns empty list when acting user is the only responsible', () {
      final activity = createActivity(responsibleUsers: ['user1']);
      final result = resolver.resolveForStateChange(activity, 'user1');
      expect(result, isEmpty);
    });
  });

  group('resolveForPost', () {
    test('excludes post author from responsible users', () {
      final activity = createActivity();
      final post = Post(
        id: 'post1',
        content: 'Hello',
        category: PostCategory.information,
        authorId: 'user2',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final result = resolver.resolveForPost(activity, post);
      expect(result, ['user1', 'user3']);
    });

    test('returns all users when author is not responsible', () {
      final activity = createActivity();
      final post = Post(
        id: 'post1',
        content: 'Hello',
        category: PostCategory.information,
        authorId: 'user99',
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final result = resolver.resolveForPost(activity, post);
      expect(result, ['user1', 'user2', 'user3']);
    });
  });

  group('resolveForAskHelp', () {
    test('returns users in target sectors', () {
      final allUsers = [
        const UserProfile(
            id: 'u1', email: 'a@b.com', nickname: 'A', sectorId: 'sectorA'),
        const UserProfile(
            id: 'u2', email: 'b@b.com', nickname: 'B', sectorId: 'sectorB'),
        const UserProfile(
            id: 'u3', email: 'c@b.com', nickname: 'C', sectorId: 'sectorA'),
        const UserProfile(
            id: 'u4', email: 'd@b.com', nickname: 'D', sectorId: 'sectorC'),
      ];
      final result =
          resolver.resolveForAskHelp(allUsers, ['sectorA', 'sectorC']);
      expect(result, ['u1', 'u3', 'u4']);
    });

    test('returns empty list when no users in target sectors', () {
      final allUsers = [
        const UserProfile(
            id: 'u1', email: 'a@b.com', nickname: 'A', sectorId: 'sectorX'),
      ];
      final result = resolver.resolveForAskHelp(allUsers, ['sectorA']);
      expect(result, isEmpty);
    });

    test('returns empty list when users list is empty', () {
      final result =
          resolver.resolveForAskHelp([], ['sectorA']);
      expect(result, isEmpty);
    });
  });

  group('buildStateChangeContent', () {
    test('includes activity title, states, and user name', () {
      final result = resolver.buildStateChangeContent(
        activityTitle: 'My Activity',
        fromState: 'Backlog',
        toState: 'Development',
        actingUserName: 'Alice',
      );
      expect(result['title'], 'My Activity');
      expect(result['body'],
          'Alice moved activity from Backlog to Development');
    });
  });

  group('buildPostContent', () {
    test('includes activity title, author name, and content', () {
      final result = resolver.buildPostContent(
        activityTitle: 'My Activity',
        postContent: 'This is a short post',
        authorName: 'Bob',
      );
      expect(result['title'], 'My Activity');
      expect(result['body'], 'Bob: This is a short post');
    });

    test('truncates post content to 200 characters', () {
      final longContent = 'A' * 300;
      final result = resolver.buildPostContent(
        activityTitle: 'My Activity',
        postContent: longContent,
        authorName: 'Bob',
      );
      expect(result['title'], 'My Activity');
      // Body should have author name + ": " + 200 chars
      expect(result['body'], 'Bob: ${'A' * 200}');
    });

    test('does not truncate content at exactly 200 characters', () {
      final exactContent = 'B' * 200;
      final result = resolver.buildPostContent(
        activityTitle: 'My Activity',
        postContent: exactContent,
        authorName: 'Charlie',
      );
      expect(result['body'], 'Charlie: ${'B' * 200}');
    });
  });
}
