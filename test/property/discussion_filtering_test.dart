import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:activity_tracker/domain/entities/post.dart';
import 'package:activity_tracker/domain/entities/post_category.dart';
import 'package:activity_tracker/domain/use_cases/filter_posts_by_category.dart';

/// Feature: activity-tracker
/// Property 16: Discussion category filtering returns only matching posts
///
/// **Validates: Requirements 6.7**
///
/// For any list of posts and any category filter value, the filtered result
/// SHALL contain only posts whose category matches the filter, and SHALL
/// contain all posts matching that category from the original list.

void main() {
  final filterPostsByCategory = FilterPostsByCategory();
  final random = Random(42); // Fixed seed for reproducibility

  // --- Generators ---

  /// Generates a random PostCategory.
  PostCategory generateCategory() {
    return PostCategory.values[random.nextInt(PostCategory.values.length)];
  }

  /// Generates a random Post with a random category.
  Post generatePost(int index) {
    final category = generateCategory();
    return Post(
      id: 'post-$index-${random.nextInt(10000)}',
      content: 'Content for post $index',
      category: category,
      authorId: 'user-${random.nextInt(100)}',
      createdAt: DateTime(2024, 1, 1).add(Duration(minutes: random.nextInt(525600))),
      targetSectors: category == PostCategory.askHelp
          ? List.generate(
              random.nextInt(3) + 1, (i) => 'sector-${random.nextInt(10)}')
          : null,
    );
  }

  /// Generates a random list of posts with length between 0 and maxLength.
  List<Post> generatePostList({int maxLength = 30}) {
    final length = random.nextInt(maxLength + 1);
    return List.generate(length, (i) => generatePost(i));
  }

  group(
    'Feature: activity-tracker, Property 16: Discussion category filtering returns only matching posts',
    () {
      test(
        'filtered result contains only posts whose category matches the filter',
        () {
          for (var i = 0; i < 150; i++) {
            final posts = generatePostList();
            final filter = generateCategory();

            final result = filterPostsByCategory.call(posts, filter);

            // Every post in the result must match the filter category
            for (final post in result) {
              expect(
                post.category,
                equals(filter),
                reason:
                    'Iteration $i: Found post with category ${post.category} '
                    'when filter was $filter (post id: ${post.id})',
              );
            }
          }
        },
      );

      test(
        'filtered result contains all posts matching the filter from the original list',
        () {
          for (var i = 0; i < 150; i++) {
            final posts = generatePostList();
            final filter = generateCategory();

            final result = filterPostsByCategory.call(posts, filter);

            // Count matching posts in original list
            final expectedMatches =
                posts.where((p) => p.category == filter).toList();

            expect(
              result.length,
              equals(expectedMatches.length),
              reason:
                  'Iteration $i: Expected ${expectedMatches.length} posts with '
                  'category $filter but got ${result.length} '
                  '(total posts: ${posts.length})',
            );

            // Verify same posts are present (by identity/equality)
            for (final expected in expectedMatches) {
              expect(
                result.contains(expected),
                isTrue,
                reason:
                    'Iteration $i: Post ${expected.id} with category '
                    '${expected.category} should be in filtered result '
                    'for filter $filter',
              );
            }
          }
        },
      );

      test(
        'null filter returns all posts unchanged',
        () {
          for (var i = 0; i < 150; i++) {
            final posts = generatePostList();

            final result = filterPostsByCategory.call(posts, null);

            expect(
              result.length,
              equals(posts.length),
              reason:
                  'Iteration $i: Null filter should return all ${posts.length} '
                  'posts but got ${result.length}',
            );

            // Verify same posts in same order
            for (var j = 0; j < posts.length; j++) {
              expect(
                result[j],
                equals(posts[j]),
                reason:
                    'Iteration $i: Post at index $j should be identical '
                    'when filter is null',
              );
            }
          }
        },
      );

      test(
        'filtered result preserves original ordering of matching posts',
        () {
          for (var i = 0; i < 150; i++) {
            final posts = generatePostList(maxLength: 50);
            final filter = generateCategory();

            final result = filterPostsByCategory.call(posts, filter);

            // Get the indices of matching posts in the original list
            final originalIndices = <int>[];
            for (var j = 0; j < posts.length; j++) {
              if (posts[j].category == filter) {
                originalIndices.add(j);
              }
            }

            // Verify count matches
            expect(result.length, equals(originalIndices.length));

            // Verify ordering is preserved
            for (var j = 0; j < result.length; j++) {
              expect(
                result[j],
                equals(posts[originalIndices[j]]),
                reason:
                    'Iteration $i: Post at filtered index $j should match '
                    'original post at index ${originalIndices[j]}',
              );
            }
          }
        },
      );

      test(
        'empty list returns empty result for any filter',
        () {
          for (var i = 0; i < 100; i++) {
            final filter = random.nextBool() ? generateCategory() : null;

            final result = filterPostsByCategory.call([], filter);

            expect(
              result,
              isEmpty,
              reason:
                  'Iteration $i: Filtering empty list with $filter should '
                  'return empty list',
            );
          }
        },
      );
    },
  );
}
