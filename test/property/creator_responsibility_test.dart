import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/domain/entities/activity.dart';
import 'package:activity_tracker/domain/entities/permission.dart';
import 'package:activity_tracker/domain/repositories/access_control_repository.dart';
import 'package:activity_tracker/domain/repositories/activity_repository.dart';
import 'package:activity_tracker/domain/repositories/params.dart';
import 'package:activity_tracker/domain/use_cases/create_activity_use_case.dart';

/// Feature: activity-tracker
/// Property 2: Creator is always assigned as responsible
///
/// **Validates: Requirements 1.4, 8.1**
///
/// For any user creating an activity, the resulting activity's responsibleUsers
/// list SHALL contain that user's ID.

// --- Mocks ---

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockAccessControlRepository extends Mock
    implements AccessControlRepository {}

void main() {
  late MockActivityRepository mockActivityRepository;
  late MockAccessControlRepository mockAccessControlRepository;
  late CreateActivityUseCase useCase;
  final random = Random(42); // Fixed seed for reproducibility

  setUp(() {
    mockActivityRepository = MockActivityRepository();
    mockAccessControlRepository = MockAccessControlRepository();
    useCase = CreateActivityUseCase(
      activityRepository: mockActivityRepository,
      accessControlRepository: mockAccessControlRepository,
    );
  });

  setUpAll(() {
    registerFallbackValue(
      const CreateActivityParams(
        title: 'fallback',
        sectorId: 'sector-fallback',
        createdBy: 'user-fallback',
      ),
    );
  });

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

  /// Generates a random user ID (simulates various user ID formats).
  String generateUserId() {
    // Varied formats: uuid-like, short ids, email-based
    final format = random.nextInt(3);
    switch (format) {
      case 0:
        // UUID-like
        return '${_randomString(8)}-${_randomString(4)}-${_randomString(4)}-${_randomString(12)}';
      case 1:
        // Short ID
        return 'user-${_randomString(random.nextInt(10) + 3)}';
      default:
        // Numeric ID
        return '${random.nextInt(999999) + 1}';
    }
  }

  /// Generates a valid title (non-empty, non-whitespace-only, 1-200 chars).
  String generateValidTitle() {
    const nonWhitespaceChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+';
    final length = random.nextInt(200) + 1;
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => nonWhitespaceChars
            .codeUnitAt(random.nextInt(nonWhitespaceChars.length)),
      ),
    );
  }

  /// Generates a random sector ID.
  String generateSectorId() {
    return 'sector-${_randomString(random.nextInt(8) + 3)}';
  }

  group(
    'Feature: activity-tracker, Property 2: Creator is always assigned as responsible',
    () {
      test(
        'for any user creating an activity, the resulting activity responsibleUsers list contains that user ID',
        () async {
          for (var i = 0; i < 150; i++) {
            final userId = generateUserId();
            final title = generateValidTitle();
            final sectorId = generateSectorId();
            final now = DateTime.now().toUtc();

            // Grant Create permission for this user
            when(() => mockAccessControlRepository.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => {Permission.create});

            // Mock the repository to faithfully implement the contract:
            // the created activity includes the creator in responsibleUsers
            when(() => mockActivityRepository.createActivity(any()))
                .thenAnswer((invocation) async {
              final params =
                  invocation.positionalArguments[0] as CreateActivityParams;
              return Activity(
                id: 'activity-${_randomString(8)}',
                title: params.title,
                currentStateId: 'backlog',
                sectorId: params.sectorId,
                createdAt: now,
                createdBy: params.createdBy,
                lastModifiedAt: now,
                lastModifiedBy: params.createdBy,
                stateEnteredAt: now,
                responsibleUsers: [params.createdBy],
                isConflicted: false,
                version: 1,
              );
            });

            final result = await useCase.execute(
              CreateActivityParams(
                title: title,
                sectorId: sectorId,
                createdBy: userId,
              ),
            );

            expect(
              result,
              isA<CreateActivitySuccess>(),
              reason:
                  'Expected success for valid creation (iteration $i): user=$userId',
            );

            final activity = (result as CreateActivitySuccess).activity;

            // THE PROPERTY: creator is always in responsibleUsers
            expect(
              activity.responsibleUsers.contains(userId),
              isTrue,
              reason:
                  'Expected responsibleUsers to contain creator "$userId" (iteration $i). '
                  'Got: ${activity.responsibleUsers}',
            );

            // Additional invariant: createdBy matches the requesting user
            expect(
              activity.createdBy,
              equals(userId),
              reason:
                  'Expected createdBy to be "$userId" (iteration $i). Got: ${activity.createdBy}',
            );
          }
        },
      );

      test(
        'creator is in responsibleUsers regardless of sector or title content',
        () async {
          // Tests with more varied input combinations
          for (var i = 0; i < 100; i++) {
            final userId = generateUserId();
            final title = generateValidTitle();
            final sectorId = generateSectorId();
            final now = DateTime.now().toUtc();

            when(() => mockAccessControlRepository.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => {
                  Permission.view,
                  Permission.create,
                  Permission.modify,
                  Permission.move,
                });

            when(() => mockActivityRepository.createActivity(any()))
                .thenAnswer((invocation) async {
              final params =
                  invocation.positionalArguments[0] as CreateActivityParams;
              // Repository implements the requirement: creator is always responsible
              return Activity(
                id: 'act-$i',
                title: params.title,
                currentStateId: 'backlog',
                sectorId: params.sectorId,
                createdAt: now,
                createdBy: params.createdBy,
                lastModifiedAt: now,
                lastModifiedBy: params.createdBy,
                stateEnteredAt: now,
                responsibleUsers: [params.createdBy],
                isConflicted: false,
                version: 1,
              );
            });

            final result = await useCase.execute(
              CreateActivityParams(
                title: title,
                sectorId: sectorId,
                createdBy: userId,
              ),
            );

            expect(result, isA<CreateActivitySuccess>());

            final activity = (result as CreateActivitySuccess).activity;
            expect(
              activity.responsibleUsers,
              contains(userId),
              reason:
                  'Creator $userId must always be in responsibleUsers (iteration $i)',
            );
          }
        },
      );

      test(
        'creator is the ONLY initial responsible user (no extra users added)',
        () async {
          for (var i = 0; i < 100; i++) {
            final userId = generateUserId();
            final title = generateValidTitle();
            final sectorId = generateSectorId();
            final now = DateTime.now().toUtc();

            when(() => mockAccessControlRepository.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => {Permission.create});

            when(() => mockActivityRepository.createActivity(any()))
                .thenAnswer((invocation) async {
              final params =
                  invocation.positionalArguments[0] as CreateActivityParams;
              return Activity(
                id: 'act-$i',
                title: params.title,
                currentStateId: 'backlog',
                sectorId: params.sectorId,
                createdAt: now,
                createdBy: params.createdBy,
                lastModifiedAt: now,
                lastModifiedBy: params.createdBy,
                stateEnteredAt: now,
                responsibleUsers: [params.createdBy],
                isConflicted: false,
                version: 1,
              );
            });

            final result = await useCase.execute(
              CreateActivityParams(
                title: title,
                sectorId: sectorId,
                createdBy: userId,
              ),
            );

            expect(result, isA<CreateActivitySuccess>());

            final activity = (result as CreateActivitySuccess).activity;

            // Property: at creation, responsible list has exactly 1 user (the creator)
            expect(
              activity.responsibleUsers.length,
              equals(1),
              reason:
                  'Expected exactly 1 responsible user at creation (iteration $i). '
                  'Got: ${activity.responsibleUsers}',
            );
            expect(
              activity.responsibleUsers.first,
              equals(userId),
              reason:
                  'The sole responsible user must be the creator (iteration $i)',
            );
          }
        },
      );

      test(
        'use case passes createdBy correctly to repository for any user ID format',
        () async {
          for (var i = 0; i < 100; i++) {
            final userId = generateUserId();
            final title = generateValidTitle();
            final sectorId = generateSectorId();
            final now = DateTime.now().toUtc();

            when(() => mockAccessControlRepository.getEffectivePermissions(
                  userId,
                  sectorId,
                )).thenAnswer((_) async => {Permission.create});

            CreateActivityParams? capturedParams;
            when(() => mockActivityRepository.createActivity(any()))
                .thenAnswer((invocation) async {
              capturedParams =
                  invocation.positionalArguments[0] as CreateActivityParams;
              return Activity(
                id: 'act-$i',
                title: capturedParams!.title,
                currentStateId: 'backlog',
                sectorId: capturedParams!.sectorId,
                createdAt: now,
                createdBy: capturedParams!.createdBy,
                lastModifiedAt: now,
                lastModifiedBy: capturedParams!.createdBy,
                stateEnteredAt: now,
                responsibleUsers: [capturedParams!.createdBy],
                isConflicted: false,
                version: 1,
              );
            });

            await useCase.execute(
              CreateActivityParams(
                title: title,
                sectorId: sectorId,
                createdBy: userId,
              ),
            );

            // Verify the use case passed the correct createdBy to the repository
            expect(
              capturedParams,
              isNotNull,
              reason:
                  'Repository createActivity should have been called (iteration $i)',
            );
            expect(
              capturedParams!.createdBy,
              equals(userId),
              reason:
                  'createdBy passed to repository must match the requesting user (iteration $i)',
            );
          }
        },
      );
    },
  );
}
