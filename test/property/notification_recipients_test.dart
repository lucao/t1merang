import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/post.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/use_cases/resolve_notification_recipients.dart';

/// Feature: activity-tracker
/// Property 19: Notification recipients exclude the acting user
///
/// **Validates: Requirements 10.1, 10.2, 10.3**
///
/// For any action (state change or post creation) performed by a user,
/// the notification recipient list SHALL equal the set of responsible users
/// for that activity minus the acting user.
///
/// Property 20: Notification content completeness and truncation
///
/// **Validates: Requirements 10.4, 10.5**
///
/// For any state-change notification, the content SHALL include the activity
/// title, previous state, new state, and acting user name. For any discussion
/// notification, the content SHALL include the activity title, post content
/// truncated to a maximum of 200 characters, and author name.

void main() {
  final resolver = ResolveNotificationRecipients();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random alphanumeric string of the given [length].
  String _randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  /// Generates a random user ID.
  String _randomUserId() {
    return 'user_${_randomString(8)}';
  }

  /// Generates a random list of unique responsible user IDs (1-20 users).
  List<String> _randomResponsibleUsers() {
    final count = random.nextInt(20) + 1; // 1 to 20
    final users = <String>{};
    while (users.length < count) {
      users.add(_randomUserId());
    }
    return users.toList();
  }

  /// Generates a random Activity with the given responsible users.
  Activity _randomActivity({List<String>? responsibleUsers}) {
    final users = responsibleUsers ?? _randomResponsibleUsers();
    return Activity(
      id: 'activity_${_randomString(6)}',
      title: _randomString(random.nextInt(200) + 1),
      currentStateId: 'state_${_randomString(4)}',
      sectorId: 'sector_${_randomString(4)}',
      createdAt: DateTime.utc(2024, 1, 1),
      createdBy: users.first,
      lastModifiedAt: DateTime.utc(2024, 1, 1),
      lastModifiedBy: users.first,
      stateEnteredAt: DateTime.utc(2024, 1, 1),
      responsibleUsers: users,
      isConflicted: false,
      version: 1,
    );
  }

  /// Generates a random Post with the specified author.
  Post _randomPost({required String authorId}) {
    return Post(
      id: 'post_${_randomString(6)}',
      content: _randomString(random.nextInt(2000) + 1),
      category:
          PostCategory.values[random.nextInt(PostCategory.values.length)],
      authorId: authorId,
      createdAt: DateTime.utc(2024, 1, 1),
    );
  }

  /// Generates a random state name.
  String _randomStateName() {
    final names = [
      'Backlog',
      'Development',
      'Production',
      'Testing',
      'Review',
      'Deployed',
      'Done',
      'In Progress',
      'Blocked',
      'QA',
    ];
    return names[random.nextInt(names.length)];
  }

  /// Generates a random user display name.
  String _randomUserName() {
    final names = [
      'Alice',
      'Bob',
      'Charlie',
      'Diana',
      'Eve',
      'Frank',
      'Grace',
      'Hank',
      'Ivy',
      'Jack',
    ];
    return '${names[random.nextInt(names.length)]}_${_randomString(3)}';
  }

  /// Generates a random post content of a specified length.
  String _randomContent(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?';
    return String.fromCharCodes(
      List.generate(
          length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // --- Property 19 Tests ---

  group(
    'Feature: activity-tracker, Property 19: Notification recipients exclude the acting user',
    () {
      test(
        'resolveForStateChange: recipients equal responsible users minus acting user',
        () {
          for (var i = 0; i < 150; i++) {
            final responsibleUsers = _randomResponsibleUsers();
            final activity =
                _randomActivity(responsibleUsers: responsibleUsers);

            // Pick acting user: sometimes from responsible list, sometimes external
            final actingUserId = random.nextBool()
                ? responsibleUsers[random.nextInt(responsibleUsers.length)]
                : _randomUserId();

            final recipients =
                resolver.resolveForStateChange(activity, actingUserId);

            // Expected: responsible users minus acting user
            final expected = responsibleUsers
                .where((uid) => uid != actingUserId)
                .toList();

            expect(
              recipients.toSet(),
              equals(expected.toSet()),
              reason:
                  'Iteration $i: recipients should be responsible users minus actingUserId. '
                  'Responsible: ${responsibleUsers.length}, '
                  'ActingUser in list: ${responsibleUsers.contains(actingUserId)}, '
                  'Expected count: ${expected.length}, Got: ${recipients.length}',
            );

            // Verify acting user is never in recipients
            expect(
              recipients.contains(actingUserId),
              isFalse,
              reason:
                  'Iteration $i: acting user should never be in recipients',
            );
          }
        },
      );

      test(
        'resolveForPost: recipients equal responsible users minus post author',
        () {
          for (var i = 0; i < 150; i++) {
            final responsibleUsers = _randomResponsibleUsers();
            final activity =
                _randomActivity(responsibleUsers: responsibleUsers);

            // Pick author: sometimes from responsible list, sometimes external
            final authorId = random.nextBool()
                ? responsibleUsers[random.nextInt(responsibleUsers.length)]
                : _randomUserId();

            final post = _randomPost(authorId: authorId);
            final recipients = resolver.resolveForPost(activity, post);

            // Expected: responsible users minus author
            final expected =
                responsibleUsers.where((uid) => uid != authorId).toList();

            expect(
              recipients.toSet(),
              equals(expected.toSet()),
              reason:
                  'Iteration $i: recipients should be responsible users minus author. '
                  'Responsible: ${responsibleUsers.length}, '
                  'Author in list: ${responsibleUsers.contains(authorId)}, '
                  'Expected count: ${expected.length}, Got: ${recipients.length}',
            );

            // Verify author is never in recipients
            expect(
              recipients.contains(authorId),
              isFalse,
              reason:
                  'Iteration $i: post author should never be in recipients',
            );
          }
        },
      );

      test(
        'when acting user is the only responsible user, recipient list is empty',
        () {
          for (var i = 0; i < 100; i++) {
            final soleUser = _randomUserId();
            final activity =
                _randomActivity(responsibleUsers: [soleUser]);

            // State change
            final stateChangeRecipients =
                resolver.resolveForStateChange(activity, soleUser);
            expect(
              stateChangeRecipients,
              isEmpty,
              reason:
                  'Iteration $i: sole responsible user performing state change should yield empty recipients',
            );

            // Post
            final post = _randomPost(authorId: soleUser);
            final postRecipients = resolver.resolveForPost(activity, post);
            expect(
              postRecipients,
              isEmpty,
              reason:
                  'Iteration $i: sole responsible user creating post should yield empty recipients',
            );
          }
        },
      );
    },
  );

  // --- Property 20 Tests ---

  group(
    'Feature: activity-tracker, Property 20: Notification content completeness and truncation',
    () {
      test(
        'buildStateChangeContent includes activity title, previous state, new state, and acting user name',
        () {
          for (var i = 0; i < 150; i++) {
            final activityTitle =
                _randomString(random.nextInt(200) + 1);
            final fromState = _randomStateName();
            final toState = _randomStateName();
            final actingUserName = _randomUserName();

            final content = resolver.buildStateChangeContent(
              activityTitle: activityTitle,
              fromState: fromState,
              toState: toState,
              actingUserName: actingUserName,
            );

            // Verify title field equals the activity title
            expect(
              content['title'],
              equals(activityTitle),
              reason:
                  'Iteration $i: notification title should be the activity title',
            );

            // Verify body contains previous state, new state, and acting user name
            final body = content['body']!;
            expect(
              body.contains(fromState),
              isTrue,
              reason:
                  'Iteration $i: body should contain previous state "$fromState". Body: "$body"',
            );
            expect(
              body.contains(toState),
              isTrue,
              reason:
                  'Iteration $i: body should contain new state "$toState". Body: "$body"',
            );
            expect(
              body.contains(actingUserName),
              isTrue,
              reason:
                  'Iteration $i: body should contain acting user name "$actingUserName". Body: "$body"',
            );
          }
        },
      );

      test(
        'buildPostContent includes activity title, author name, and truncates content to max 200 chars',
        () {
          for (var i = 0; i < 150; i++) {
            final activityTitle =
                _randomString(random.nextInt(200) + 1);
            final authorName = _randomUserName();

            // Generate content of varying lengths: some under, some at, some over 200
            final contentLength = random.nextInt(500) + 1;
            final postContent = _randomContent(contentLength);

            final content = resolver.buildPostContent(
              activityTitle: activityTitle,
              postContent: postContent,
              authorName: authorName,
            );

            // Verify title field equals the activity title
            expect(
              content['title'],
              equals(activityTitle),
              reason:
                  'Iteration $i: notification title should be the activity title',
            );

            // Verify body contains author name
            final body = content['body']!;
            expect(
              body.contains(authorName),
              isTrue,
              reason:
                  'Iteration $i: body should contain author name "$authorName". Body length: ${body.length}',
            );

            // Verify truncation: post content portion should be at most 200 chars
            final expectedTruncatedContent = postContent.length > 200
                ? postContent.substring(0, 200)
                : postContent;
            expect(
              body.contains(expectedTruncatedContent),
              isTrue,
              reason:
                  'Iteration $i: body should contain truncated content. '
                  'Original length: $contentLength, '
                  'Expected truncated length: ${expectedTruncatedContent.length}',
            );

            // Verify the post content in the body is never longer than 200 chars
            // The body format is "$authorName: $truncatedContent"
            final expectedBody = '$authorName: $expectedTruncatedContent';
            expect(
              body,
              equals(expectedBody),
              reason:
                  'Iteration $i: body should match expected format. '
                  'Content length: $contentLength',
            );
          }
        },
      );

      test(
        'buildPostContent: content at exactly 200 characters is not truncated',
        () {
          for (var i = 0; i < 100; i++) {
            final activityTitle =
                _randomString(random.nextInt(200) + 1);
            final authorName = _randomUserName();
            final postContent = _randomContent(200);

            final content = resolver.buildPostContent(
              activityTitle: activityTitle,
              postContent: postContent,
              authorName: authorName,
            );

            final body = content['body']!;
            final expectedBody = '$authorName: $postContent';
            expect(
              body,
              equals(expectedBody),
              reason:
                  'Iteration $i: exactly 200-char content should not be truncated',
            );
          }
        },
      );

      test(
        'buildPostContent: content over 200 characters is truncated to exactly 200',
        () {
          for (var i = 0; i < 100; i++) {
            final activityTitle =
                _randomString(random.nextInt(200) + 1);
            final authorName = _randomUserName();

            // Always generate content > 200 chars
            final contentLength = random.nextInt(1800) + 201;
            final postContent = _randomContent(contentLength);

            final content = resolver.buildPostContent(
              activityTitle: activityTitle,
              postContent: postContent,
              authorName: authorName,
            );

            final body = content['body']!;
            final truncated = postContent.substring(0, 200);
            final expectedBody = '$authorName: $truncated';
            expect(
              body,
              equals(expectedBody),
              reason:
                  'Iteration $i: content of length $contentLength should be truncated to 200. '
                  'Body length: ${body.length}, Expected: ${expectedBody.length}',
            );
          }
        },
      );
    },
  );
}
