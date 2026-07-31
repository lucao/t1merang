# Implementation Plan: Activity Tracker

## Overview

This plan implements a cross-platform Kanban board application using Flutter + Firebase (Firestore, Cloud Functions, FCM, Auth) with Clean Architecture (Presentation → Domain → Data → Infrastructure). Tasks are organized from foundational setup through domain logic, data layer, Cloud Functions, and finally UI integration.

## Tasks

- [x] 1. Set up project structure and core interfaces
  - [x] 1.1 Initialize Flutter project with Clean Architecture directory structure
    - Create `lib/domain/`, `lib/data/`, `lib/infrastructure/`, `lib/presentation/` directories
    - Create `lib/domain/entities/`, `lib/domain/repositories/`, `lib/domain/use_cases/`, `lib/domain/validators/`
    - Create `lib/data/models/`, `lib/data/datasources/`, `lib/data/repositories/`
    - Create `lib/infrastructure/firebase/`, `lib/infrastructure/services/`
    - Create `lib/presentation/blocs/`, `lib/presentation/pages/`, `lib/presentation/widgets/`
    - Create `test/unit/`, `test/property/`, `test/integration/`, `test/e2e/` directories
    - Add dependencies to `pubspec.yaml`: `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_messaging`, `flutter_bloc`, `equatable`, `fast_check` (dev), `bloc_test` (dev), `mocktail` (dev)
    - _Requirements: 12.1, 12.2_

  - [x] 1.2 Define domain entities
    - Create `Activity`, `KanbanState`, `Post`, `TimelineEntry`, `Conflict`, `ConflictVersion`, `UserProfile`, `AppNotification` entity classes
    - Define enums: `PostCategory`, `SortOrder`, `ConflictStatus`, `Permission`
    - Define `ActivityTrackerError` enum with all error codes
    - _Requirements: 1.1, 4.1, 5.1, 6.1, 7.1, 13.4_

  - [x] 1.3 Define repository abstract classes
    - Create `ActivityRepository`, `StateRepository`, `DiscussionRepository`, `ConflictRepository`, `UserRepository`, `NotificationRepository`, `AccessControlRepository` abstract classes in `lib/domain/repositories/`
    - Define method signatures as specified in the design document
    - _Requirements: 1.1, 2.1, 3.1, 4.2, 6.2, 7.3, 8.1, 9.1, 10.1, 11.1, 13.4_

- [x] 2. Implement domain validators and core business logic
  - [x] 2.1 Implement title validation
    - Create `TitleValidator` in `lib/domain/validators/title_validator.dart`
    - Accept strings that are non-empty, not whitespace-only, and between 1–200 characters
    - Reject empty, whitespace-only, or >200 character strings
    - Return typed error (`titleRequired` or `titleTooLong`)
    - _Requirements: 1.1, 1.6, 2.2, 2.4_

  - [x] 2.2 Write property test for title validation
    - **Property 1: Title validation accepts and rejects correctly**
    - **Validates: Requirements 1.1, 1.6, 2.2, 2.4**

  - [x] 2.3 Implement post content and category validation
    - Create `PostValidator` in `lib/domain/validators/post_validator.dart`
    - Validate content is 1–2000 characters and category is selected
    - For Ask_Help posts, validate 1–10 target sectors are specified
    - Return typed errors (`postContentRequired`, `sectorRequired`)
    - _Requirements: 6.2, 6.4, 6.6, 6.8_

  - [x] 2.4 Write property tests for post validation
    - **Property 14: Post content validation**
    - **Validates: Requirements 6.2, 6.6**
    - **Property 15: Ask_Help post requires 1 to 10 target sectors**
    - **Validates: Requirements 6.4, 6.8**

  - [x] 2.5 Implement user profile validation
    - Create `UserValidator` in `lib/domain/validators/user_validator.dart`
    - Validate email format (max 254 chars), nickname (1–50 chars), sector specified
    - Case-insensitive email uniqueness check (delegate to repository)
    - _Requirements: 7.1, 7.2, 7.6_

  - [x] 2.6 Write property tests for user profile validation
    - **Property 17: User profile field validation**
    - **Validates: Requirements 7.1**
    - **Property 18: Email uniqueness enforcement (case-insensitive)**
    - **Validates: Requirements 7.2, 7.6**

  - [x] 2.7 Implement state name validation
    - Create `StateValidator` in `lib/domain/validators/state_validator.dart`
    - Validate name is 1–50 characters
    - Case-insensitive uniqueness check against existing state names
    - Enforce maximum of 10 states per board
    - _Requirements: 4.2, 4.3, 4.8_

  - [x] 2.8 Write property test for state name validation
    - **Property 10: State name validation and case-insensitive uniqueness**
    - **Validates: Requirements 4.2, 4.3**

- [ ] 3. Checkpoint - Ensure all validator tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement domain use cases - activity lifecycle
  - [x] 4.1 Implement CreateActivity use case
    - Create `CreateActivityUseCase` in `lib/domain/use_cases/`
    - Validate title, check Create permission, set initial state to Backlog
    - Assign creator as responsible user, initialize empty discussion and timeline
    - Record creation timestamp in UTC with second precision
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 8.1, 11.4_

  - [x] 4.2 Write property test for creator responsibility assignment
    - **Property 2: Creator is always assigned as responsible**
    - **Validates: Requirements 1.4, 8.1**

  - [x] 4.3 Implement MoveActivity use case
    - Create `MoveActivityUseCase` in `lib/domain/use_cases/`
    - Check Move permission, update activity state to target
    - Add mover to responsible users if not already present (no duplicates)
    - Record transition timestamp and duration in timeline
    - Trigger notification to other responsible users
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 8.2, 8.3_

  - [x] 4.4 Write property tests for state transition and responsibility
    - **Property 5: State transition updates current state**
    - **Validates: Requirements 3.1**
    - **Property 6: Mover auto-assignment to responsibility list**
    - **Validates: Requirements 3.3, 8.2**
    - **Property 7: No duplicate entries in responsibility list**
    - **Validates: Requirements 8.3**

  - [x] 4.5 Implement WithdrawResponsibility use case
    - Create `WithdrawResponsibilityUseCase` in `lib/domain/use_cases/`
    - Prevent withdrawal if user is the last responsible user
    - Remove user from responsibility list otherwise
    - _Requirements: 8.4, 8.5, 8.6_

  - [x] 4.6 Write property tests for responsibility withdrawal
    - **Property 8: Withdrawal removes user from responsibility list**
    - **Validates: Requirements 8.5**
    - **Property 9: Last responsible user cannot withdraw**
    - **Validates: Requirements 8.6**

  - [x] 4.7 Implement UpdateActivityTitle use case
    - Create `UpdateActivityTitleUseCase` in `lib/domain/use_cases/`
    - Validate new title, check Modify permission, check conflict lock
    - Persist change, record modifying user identity
    - _Requirements: 2.2, 2.4, 2.5, 13.10_

  - [x] 4.8 Write property test for conflict field lock
    - **Property 25: Conflicted activity fields are locked from modification**
    - **Validates: Requirements 13.10**

- [x] 5. Implement domain use cases - supporting features
  - [x] 5.1 Implement permission resolution logic
    - Create `GetEffectivePermissionsUseCase` in `lib/domain/use_cases/`
    - User-level permissions take precedence over sector-level
    - New users have no permissions by default
    - Prevent permission changes that eliminate last full-admin
    - _Requirements: 11.1, 11.2, 11.7, 11.8_

  - [x] 5.2 Write property tests for permission logic
    - **Property 4: Permission enforcement blocks unauthorized actions**
    - **Validates: Requirements 2.5, 3.6, 9.3, 11.3, 11.4, 11.5, 11.6**
    - **Property 21: User-level permissions take precedence over sector-level**
    - **Validates: Requirements 11.2**
    - **Property 22: Permission revocation rejected when it eliminates last admin**
    - **Validates: Requirements 11.7**

  - [x] 5.3 Implement Kanban board grouping and sorting logic
    - Create `GroupActivitiesByState` utility in `lib/domain/use_cases/`
    - Group activities by currentStateId into columns
    - Sort within each column by state's configured sortOrder
    - For Production state, filter out activities older than threshold
    - _Requirements: 2.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 5.4 Write property tests for grouping and sorting
    - **Property 3: Activities are grouped into correct state columns**
    - **Validates: Requirements 2.3**
    - **Property 11: State-specific activity sorting and threshold filtering**
    - **Validates: Requirements 4.5, 4.6, 4.7**

  - [x] 5.5 Implement timeline duration calculation
    - Create `CalculateDuration` utility in `lib/domain/use_cases/`
    - Calculate floor((exit - entry) / 60) for minute-level precision
    - Aggregate cumulative time per state from timeline entries
    - Include current state elapsed time (entry to now)
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 5.6 Write property tests for duration calculation
    - **Property 12: Duration calculation with minute-level floor precision**
    - **Validates: Requirements 5.1, 5.3**
    - **Property 13: Cumulative time aggregation per state**
    - **Validates: Requirements 5.2**

  - [x] 5.7 Implement notification recipient resolution
    - Create `ResolveNotificationRecipients` utility in `lib/domain/use_cases/`
    - For state changes: all responsible users minus acting user
    - For posts: all responsible users minus author
    - For Ask_Help: all users in target sectors
    - Build notification content with required fields (title, states, user name, truncated post content at 200 chars)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 5.8 Write property tests for notification logic
    - **Property 19: Notification recipients exclude the acting user**
    - **Validates: Requirements 10.1, 10.2, 10.3**
    - **Property 20: Notification content completeness and truncation**
    - **Validates: Requirements 10.4, 10.5**

  - [x] 5.9 Implement discussion filtering
    - Create `FilterPostsByCategory` utility in `lib/domain/use_cases/`
    - Filter posts by selected category, return all matching posts
    - _Requirements: 6.7_

  - [x] 5.10 Write property test for discussion filtering
    - **Property 16: Discussion category filtering returns only matching posts**
    - **Validates: Requirements 6.7**

- [ ] 6. Checkpoint - Ensure all domain logic tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement conflict resolution logic
  - [x] 7.1 Implement ConflictResolution use case
    - Create `ResolveConflictUseCase` in `lib/domain/use_cases/`
    - Apply version with most votes when quorum reached or deadline expires
    - Fallback to most recent timestamp when no votes cast
    - Tie-breaking: most recent timestamp among tied versions
    - _Requirements: 13.7, 13.8, 13.9_

  - [x] 7.2 Write property test for conflict resolution
    - **Property 24: Conflict resolution applies majority with timestamp fallback**
    - **Validates: Requirements 13.7, 13.8, 13.9**

  - [x] 7.3 Implement CastVote use case
    - Create `CastVoteUseCase` in `lib/domain/use_cases/`
    - Allow each user exactly one vote per conflict
    - Reject duplicate votes, preserve existing vote
    - _Requirements: 13.6_

  - [x] 7.4 Write property test for vote uniqueness
    - **Property 23: Each user may cast exactly one vote per conflict**
    - **Validates: Requirements 13.6**

- [x] 8. Implement data layer - Firestore integration
  - [x] 8.1 Create Firestore DTOs and serialization
    - Create model classes in `lib/data/models/` for each Firestore document: `ActivityModel`, `StateModel`, `PostModel`, `TimelineEntryModel`, `ConflictModel`, `UserModel`, `NotificationModel`, `PermissionModel`
    - Implement `toFirestore()` and `fromFirestore()` for each model
    - _Requirements: 13.1_

  - [x] 8.2 Implement ActivityRepository with Firestore
    - Create `FirestoreActivityRepository` in `lib/data/repositories/`
    - Implement `watchActivitiesBySector` using Firestore real-time snapshots
    - Implement `createActivity`, `updateActivity`, `moveActivity` with optimistic concurrency (version field)
    - Support offline write queuing via Firestore persistence
    - _Requirements: 1.1, 1.2, 2.2, 3.1, 12.3, 12.4, 12.6, 13.1_

  - [x] 8.3 Implement StateRepository with Firestore
    - Create `FirestoreStateRepository` in `lib/data/repositories/`
    - Implement `watchStates`, `createState`, enforce max 10 states
    - Seed default states (Backlog, Development, Production) on first run
    - _Requirements: 4.1, 4.2, 4.8_

  - [x] 8.4 Implement DiscussionRepository with Firestore
    - Create `FirestoreDiscussionRepository` in `lib/data/repositories/`
    - Implement `watchPosts` with category filter support
    - Implement `createPost` as subcollection document creation
    - _Requirements: 6.2, 6.3, 6.7_

  - [x] 8.5 Implement ConflictRepository with Firestore
    - Create `FirestoreConflictRepository` in `lib/data/repositories/`
    - Implement `watchActiveConflicts`, `castVote`
    - Handle conflict document creation and status updates
    - _Requirements: 13.4, 13.5, 13.6, 13.10_

  - [x] 8.6 Implement UserRepository and AccessControlRepository with Firestore
    - Create `FirestoreUserRepository` and `FirestoreAccessControlRepository` in `lib/data/repositories/`
    - Implement profile CRUD, email uniqueness check, permission queries
    - _Requirements: 7.1, 7.2, 9.1, 11.1, 11.2_

  - [x] 8.7 Implement NotificationRepository with Firestore and FCM
    - Create `FirestoreNotificationRepository` in `lib/data/repositories/`
    - Implement `watchNotifications`, `markAsRead`
    - Integrate FCM for push notification token management
    - _Requirements: 10.1, 10.2, 10.3_

- [ ] 9. Checkpoint - Ensure data layer compiles and basic integration works
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement Cloud Functions
  - [ ] 10.1 Implement onActivityStateChange function
    - Create Cloud Function triggered on Firestore `activities/{activityId}` update
    - Detect state change, calculate duration for previous state, create timeline entry
    - Check for version conflicts (optimistic concurrency violation)
    - Create in-app notifications for responsible users (within 10 seconds)
    - Queue email notifications (within 5 minutes)
    - _Requirements: 3.2, 3.4, 3.5, 5.1, 10.1, 10.2, 10.4_

  - [ ] 10.2 Implement onPostCreated function
    - Create Cloud Function triggered on Firestore `activities/{activityId}/posts/{postId}` creation
    - Send in-app notification to responsible users (excluding author) within 10 seconds
    - For Ask_Help posts, send notifications to all users in target sectors within 30 seconds
    - Include truncated content (max 200 chars) in notification body
    - _Requirements: 6.5, 10.3, 10.5_

  - [ ] 10.3 Implement conflict detection and resolution functions
    - Create `onConflictCreated` function: start voting timer, notify responsible users
    - Create `resolveConflict` scheduled function: check quorum or deadline, apply resolution
    - Log all conflict events to auditLog collection
    - _Requirements: 13.4, 13.5, 13.6, 13.7, 13.8, 13.9, 13.10, 13.11, 13.12_

  - [ ] 10.4 Implement email notification function with retry
    - Create `sendEmailNotification` function triggered by Pub/Sub
    - Integrate with SendGrid API for email delivery
    - Retry up to 3 times with 1-minute intervals on failure
    - Update email queue document status
    - _Requirements: 10.1, 10.6_

  - [ ] 10.5 Implement cleanupProductionState scheduled function
    - Create daily scheduled function to archive activities past Production threshold
    - Read configurable threshold (default 30 days, range 1–365)
    - Filter and archive expired activities
    - _Requirements: 4.7_

- [ ] 11. Implement BLoC state management
  - [ ] 11.1 Implement AuthBloc
    - Create `AuthBloc` in `lib/presentation/blocs/auth/`
    - Handle Login, Logout, CheckAuth events
    - Manage Authenticated, Unauthenticated, AuthLoading states
    - Integrate with Firebase Auth
    - _Requirements: 11.9_

  - [ ] 11.2 Implement KanbanBloc
    - Create `KanbanBloc` in `lib/presentation/blocs/kanban/`
    - Handle LoadBoard, MoveActivity, ChangeFilter, RefreshBoard events
    - Subscribe to real-time activity stream filtered by sector
    - Apply grouping, sorting, and threshold filtering
    - Check permissions before allowing actions
    - _Requirements: 2.3, 3.1, 9.1, 9.2, 9.4_

  - [ ] 11.3 Implement ActivityBloc
    - Create `ActivityBloc` in `lib/presentation/blocs/activity/`
    - Handle LoadActivity, UpdateTitle, AddPost, WithdrawResponsibility events
    - Manage activity detail state with discussion, timeline, and responsible users
    - _Requirements: 2.1, 2.2, 6.2, 8.5_

  - [ ] 11.4 Implement ConflictBloc
    - Create `ConflictBloc` in `lib/presentation/blocs/conflict/`
    - Handle LoadConflicts, CastVote, DismissResolved events
    - Watch active conflicts for current user
    - _Requirements: 13.5, 13.6_

  - [ ] 11.5 Write unit tests for BLoCs
    - Test KanbanBloc state transitions (Loading → Loaded → Error)
    - Test ActivityBloc event handling and state emissions
    - Test ConflictBloc voting flow
    - Test AuthBloc authentication state transitions
    - _Requirements: 2.3, 3.1, 9.1, 13.5_

- [ ] 12. Implement presentation layer (UI)
  - [ ] 12.1 Implement KanbanBoardPage
    - Create responsive Kanban board with columns per state
    - Implement drag-and-drop for activity state transitions
    - Add sector filter dropdown at top
    - Horizontal scroll on mobile, full grid on desktop
    - Display empty-state indicator when sector has no activities
    - Show offline indicator and syncing badge
    - _Requirements: 2.3, 3.1, 9.1, 9.2, 9.4, 9.5, 12.1, 12.2_

  - [ ] 12.2 Implement ActivityDetailPage
    - Create activity detail view with editable title
    - Tabbed interface: Discussion / Timeline / Details
    - Display responsible users list with withdraw option
    - Show conflict indicator when activity is conflicted
    - Inline validation errors for title edits
    - _Requirements: 2.1, 2.2, 2.4, 5.2, 5.4, 8.5, 8.6, 13.10_

  - [ ] 12.3 Implement Discussion section UI
    - Create post creation form with category selector
    - Implement Ask_Help sector multi-select (1–10 sectors)
    - Display posts with category badges and timestamps
    - Add category filter controls
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.7, 6.8_

  - [ ] 12.4 Implement ConflictResolutionDialog
    - Display conflicting versions side by side
    - Show author, timestamp, and diff highlights for each version
    - Voting buttons with countdown timer showing remaining time
    - Display vote count progress
    - _Requirements: 13.5, 13.6_

  - [ ] 12.5 Implement NotificationPanel
    - Create in-app notification list with mark-as-read
    - Display badge count on app bar
    - Navigate to relevant activity on notification tap
    - _Requirements: 10.2, 10.3_

  - [ ] 12.6 Implement User Profile and Admin pages
    - Create user profile page showing responsible activities, posts, and transitions
    - Create admin page for permission management (grant/revoke per user or sector)
    - Create state management page for creating custom states and configuring sort order
    - _Requirements: 7.3, 7.4, 7.5, 4.2, 4.4, 11.1, 11.2_

  - [ ] 12.7 Implement Activity Creation dialog/page
    - Create new activity form with title input and validation
    - Display inline error for empty/whitespace-only/too-long title
    - Preserve entered data on validation failure
    - _Requirements: 1.1, 1.6_

- [ ] 13. Implement real-time sync and offline support
  - [ ] 13.1 Configure Firestore offline persistence
    - Enable Firestore offline persistence for mobile and desktop
    - Implement offline write queue with optimistic UI updates
    - Show visual indicator for offline mode and pending syncs
    - Handle reconnection sync within 10 seconds
    - _Requirements: 12.3, 12.4, 12.6_

  - [ ] 13.2 Implement Firestore security rules
    - Write security rules enforcing permission checks (View, Create, Modify, Move)
    - Enforce optimistic concurrency version check on activity writes
    - Enforce field-level locking for conflicted activities
    - Enforce permission revocation takes effect on next action
    - _Requirements: 11.3, 11.4, 11.5, 11.6, 11.9, 13.10_

- [ ] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Cloud Functions (task 10) can be developed in parallel with the Flutter UI (tasks 11-12) since they interact through Firestore
- The `fast_check` Dart package is used for property-based testing

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1", "2.3", "2.5", "2.7"] },
    { "id": 3, "tasks": ["2.2", "2.4", "2.6", "2.8"] },
    { "id": 4, "tasks": ["4.1", "4.3", "4.5", "4.7", "5.1", "5.3", "5.5", "5.7", "5.9"] },
    { "id": 5, "tasks": ["4.2", "4.4", "4.6", "4.8", "5.2", "5.4", "5.6", "5.8", "5.10"] },
    { "id": 6, "tasks": ["7.1", "7.3"] },
    { "id": 7, "tasks": ["7.2", "7.4"] },
    { "id": 8, "tasks": ["8.1"] },
    { "id": 9, "tasks": ["8.2", "8.3", "8.4", "8.5", "8.6", "8.7"] },
    { "id": 10, "tasks": ["10.1", "10.2", "10.3", "10.4", "10.5"] },
    { "id": 11, "tasks": ["11.1", "11.2", "11.3", "11.4"] },
    { "id": 12, "tasks": ["11.5"] },
    { "id": 13, "tasks": ["12.1", "12.2", "12.3", "12.4", "12.5", "12.6", "12.7"] },
    { "id": 14, "tasks": ["13.1", "13.2"] }
  ]
}
```
