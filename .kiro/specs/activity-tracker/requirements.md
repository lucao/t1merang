# Requirements Document

## Introduction

Activity Tracker is a cross-platform application (desktop and mobile) that provides a Kanban board for tracking work activities. Users can create, view, modify, and move activities through customizable states. The system supports collaboration through discussions, responsibility assignment, email/notification sharing, time tracking per state, and sector-based access control.

## Glossary

- **Activity_Tracker**: The cross-platform application (desktop and mobile) that manages activities on a Kanban board
- **Activity**: A work item on the Kanban board with a title, discussion section, timeline, and assigned state
- **Kanban_Board**: A visual board displaying activities organized by their current state as columns
- **State**: A user-defined column on the Kanban board representing a phase in the workflow (e.g., Backlog, Development, Production)
- **Discussion**: A section within an activity containing posts categorized as Information, Complaint, or Ask_Help
- **Post**: A single message within an activity's discussion, associated with a category and a user
- **Timeline**: A record tracking the cumulative time an activity has spent in each state
- **User**: A person with an email, nickname, and sector who interacts with the system
- **Sector**: An organizational grouping assigned to users, used for filtering the Kanban board and requesting cross-sector help
- **Responsibility**: The association between a user and an activity, indicating the user is accountable for that activity
- **Notification**: An in-app alert sent to relevant users when a state change or update occurs
- **Access_Control**: The permission system governing who can view, create, modify, and move activities on a Kanban board
- **Serverless_Storage**: A cloud-based data persistence layer that requires no dedicated server provisioning or management, scaling automatically with demand
- **Democratic_Conflict_Resolution**: A consensus-based mechanism for resolving conflicting data modifications, where conflicting versions are presented to relevant users and the version receiving majority agreement is applied
- **Conflict**: A state in which two or more concurrent modifications to the same data item are detected during synchronization
- **Consensus_Quorum**: The minimum number of participating users required to reach a valid resolution decision, defined as a simple majority (more than 50%) of the responsible users for the affected activity

## Requirements

### Requirement 1: Activity Creation

**User Story:** As a user, I want to create new activities on the Kanban board, so that I can track work items through their lifecycle.

#### Acceptance Criteria

1. WHEN a user creates a new activity, THE Activity_Tracker SHALL require a title containing between 1 and 200 non-whitespace-only characters for the activity
2. WHEN a new activity is created, THE Activity_Tracker SHALL place the activity in the Backlog state by default
3. WHEN a new activity is created, THE Activity_Tracker SHALL record the creation timestamp in UTC with second precision
4. WHEN a new activity is created, THE Activity_Tracker SHALL associate the creating user as responsible for the activity
5. WHEN a new activity is created, THE Activity_Tracker SHALL initialize an empty discussion section and an empty timeline for the activity
6. IF a user submits an activity without a title or with a whitespace-only title, THEN THE Activity_Tracker SHALL reject the creation, display an error message indicating that a title is required, and preserve any other entered data

### Requirement 2: Activity Viewing and Modification

**User Story:** As a user, I want to view and modify activities, so that I can keep activity details up to date.

#### Acceptance Criteria

1. WHEN a user opens an activity, THE Activity_Tracker SHALL display the activity title, current state, discussion section with categorized posts, timeline showing time spent in each state, and the list of responsible users assigned to the activity
2. WHEN a user modifies an activity title to a new value between 1 and 200 characters, THE Activity_Tracker SHALL persist the change, record the identity of the modifying user, and display the updated title within 2 seconds
3. THE Activity_Tracker SHALL display the Kanban board with activities grouped by their current state as columns, where columns are ordered according to the defined state sequence
4. IF a user submits an activity title that is empty or exceeds 200 characters, THEN THE Activity_Tracker SHALL reject the modification, retain the previous title, and display an error message indicating the title length constraint
5. IF a user without modification permission attempts to modify an activity title, THEN THE Activity_Tracker SHALL reject the modification, retain the previous title, and indicate that the user lacks permission to perform the change

### Requirement 3: Activity State Transitions

**User Story:** As a user, I want to move activities between states on the Kanban board, so that I can reflect the progress of work items.

#### Acceptance Criteria

1. WHEN a user moves an activity to a different state, THE Activity_Tracker SHALL update the activity's current state to the target state and visually relocate the activity to the corresponding column on the Kanban board within 2 seconds
2. WHEN a user moves an activity to a different state, THE Activity_Tracker SHALL record the transition timestamp in UTC with second precision in the activity timeline, including the source state and target state
3. WHEN a user moves an activity to a different state and that user is not already in the responsible users list, THE Activity_Tracker SHALL add that user to the list of responsible users for the activity
4. WHEN a user moves an activity to a different state, THE Activity_Tracker SHALL send an in-app notification within 10 seconds to all other responsible users of that activity
5. WHEN a user moves an activity to a different state, THE Activity_Tracker SHALL send an email within 5 minutes to all other responsible users of that activity
6. IF a user without Move permission attempts to move an activity, THEN THE Activity_Tracker SHALL deny the action, preserve the activity in its original state, and display an authorization error message

### Requirement 4: Custom State Management

**User Story:** As a user, I want to create and manage custom states for the Kanban board, so that the workflow matches my team's process.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL provide three default states: Backlog, Development, and Production, displayed as columns on the Kanban board in that order from left to right
2. WHEN a user creates a new state with a unique name between 1 and 50 characters, THE Activity_Tracker SHALL add the state as a new column on the Kanban board
3. IF a user attempts to create a state with a name that already exists (case-insensitive), THEN THE Activity_Tracker SHALL reject the creation and display an error message indicating the name is already in use
4. WHEN a user defines a state, THE Activity_Tracker SHALL allow the user to specify a default sort order for activities within that state from the following options: oldest entered date first, most recent entered date first
5. WHILE the Backlog state is displayed, THE Activity_Tracker SHALL sort activities by oldest entered date first by default
6. WHILE the Development state is displayed, THE Activity_Tracker SHALL sort activities by most recent entered date first by default
7. WHILE the Production state is displayed, THE Activity_Tracker SHALL sort activities by most recent entered date first and filter out activities whose entry date into the Production state is older than a configurable threshold, which defaults to 30 days and may be set between 1 and 365 days
8. THE Activity_Tracker SHALL support a maximum of 10 states (including the 3 default states) per Kanban board

### Requirement 5: Activity Timeline

**User Story:** As a user, I want to see how much time an activity spent in each state, so that I can identify bottlenecks in my workflow.

#### Acceptance Criteria

1. WHEN an activity transitions to a new state, THE Activity_Tracker SHALL record the duration spent in the previous state, calculated as the difference between the current transition timestamp and the previous entry timestamp, with minute-level precision
2. WHEN a user views an activity's timeline, THE Activity_Tracker SHALL display the cumulative time spent in each state the activity has occupied, ordered by the sequence of states visited
3. THE Activity_Tracker SHALL calculate timeline durations with minute-level precision, rounding partial minutes down
4. WHEN a user views an activity's timeline, THE Activity_Tracker SHALL include the current state's elapsed time calculated as the difference between the state entry timestamp and the current time

### Requirement 6: Discussion Section

**User Story:** As a user, I want to have categorized discussions within an activity, so that conversations are organized by purpose.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL provide three discussion categories: Information, Complaint, and Ask_Help
2. WHEN a user creates a post in a discussion, THE Activity_Tracker SHALL require the user to select one category from Information, Complaint, or Ask_Help and provide post content between 1 and 2000 characters
3. WHEN a user creates a post in a discussion, THE Activity_Tracker SHALL associate the post with the authoring user and record the creation timestamp
4. WHEN a user creates an Ask_Help post, THE Activity_Tracker SHALL require the user to specify at least one and up to 10 target sectors to request assistance from
5. WHEN an Ask_Help post targets a sector, THE Activity_Tracker SHALL send an in-app notification to all users in that sector within 30 seconds, including the post content, the authoring user, and the activity name
6. IF a user submits a post with empty content or without selecting a category, THEN THE Activity_Tracker SHALL reject the submission and display an error message indicating the missing required fields
7. WHEN a user views a discussion within an activity, THE Activity_Tracker SHALL allow filtering posts by category
8. IF a user creates an Ask_Help post without specifying at least one target sector, THEN THE Activity_Tracker SHALL reject the submission and display an error message indicating that at least one target sector is required

### Requirement 7: User Management

**User Story:** As a user, I want to have a profile with my email, nickname, and sector, so that the system can identify me and associate my interactions.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL store for each user: an email address (valid format, max 254 characters), a nickname (1 to 50 characters), and a sector
2. THE Activity_Tracker SHALL enforce uniqueness of email addresses across all users (case-insensitive comparison)
3. WHEN a user views their profile, THE Activity_Tracker SHALL display all activities the user is responsible for, ordered by most recent state transition date first
4. WHEN a user views their profile, THE Activity_Tracker SHALL display all posts authored by that user, ordered by creation date descending
5. WHEN a user views their profile, THE Activity_Tracker SHALL display all state transitions performed by that user, ordered by transition date descending
6. IF a user attempts to register with an email already associated with another account, THEN THE Activity_Tracker SHALL reject the registration and display an error message indicating the email is already in use

### Requirement 8: Responsibility Management

**User Story:** As a user, I want to manage responsibility assignments on activities, so that accountability is clear and flexible.

#### Acceptance Criteria

1. WHEN a user creates an activity, THE Activity_Tracker SHALL assign that user as the initial responsible user for the activity
2. WHEN a user moves an activity and that user is not already in the activity's responsible users list, THE Activity_Tracker SHALL add that user to the activity's responsible users list
3. WHEN a user moves an activity and that user is already in the activity's responsible users list, THE Activity_Tracker SHALL retain the existing assignment without creating a duplicate entry
4. THE Activity_Tracker SHALL allow up to 20 users to be responsible for a single activity simultaneously
5. WHEN a responsible user requests to withdraw from an activity, THE Activity_Tracker SHALL remove that user from the activity's responsible users list
6. IF a withdrawal would result in zero responsible users, THEN THE Activity_Tracker SHALL prevent the withdrawal and display an error message indicating that at least one responsible user is required

### Requirement 9: Sector-Based Filtering

**User Story:** As a user, I want the Kanban board filtered by sector, so that I can focus on work relevant to my team.

#### Acceptance Criteria

1. WHEN a user opens the Kanban board, THE Activity_Tracker SHALL display only activities associated with the user's assigned sector, with the sector filter pre-selected to the user's own sector
2. WHEN a user selects a different sector from the sector filter, THE Activity_Tracker SHALL replace the displayed activities with only those associated with the newly selected sector within 2 seconds
3. IF a user selects a sector they do not have permission to view, THEN THE Activity_Tracker SHALL display a message indicating access is denied and SHALL retain the previously displayed sector's activities
4. IF the selected sector has no activities, THEN THE Activity_Tracker SHALL display an empty-state indication on the Kanban board
5. IF a user has no assigned sector, THEN THE Activity_Tracker SHALL prompt the user to select a sector before displaying the Kanban board

### Requirement 10: Email and Notification Sharing

**User Story:** As a user, I want to receive emails and in-app notifications about activity changes, so that I stay informed without constantly checking the board.

#### Acceptance Criteria

1. WHEN an activity's state changes, THE Activity_Tracker SHALL send an email notification within 5 minutes to all responsible users of that activity, excluding the user who made the change
2. WHEN an activity's state changes, THE Activity_Tracker SHALL send an in-app notification within 10 seconds to all responsible users of that activity, excluding the user who made the change
3. WHEN a new post is added to an activity discussion, THE Activity_Tracker SHALL send an in-app notification within 10 seconds to all responsible users of that activity, excluding the user who authored the post
4. THE Activity_Tracker SHALL include the activity title, the previous state, the new state, and the name of the user who made the change in each state-change notification (both email and in-app)
5. THE Activity_Tracker SHALL include the activity title, the discussion post content (truncated to a maximum of 200 characters), and the name of the user who authored the post in each discussion notification
6. IF an email notification fails to deliver, THEN THE Activity_Tracker SHALL retry delivery up to 3 times with a minimum interval of 1 minute between attempts, and shall preserve the corresponding in-app notification regardless of email delivery outcome

### Requirement 11: Access Control

**User Story:** As an administrator, I want to control who can view, create, modify, and move activities, so that the board remains secure and organized.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL define four access permissions: View (ability to see the Kanban board and its activities), Create (ability to add new activities), Modify (ability to edit activity fields), and Move (ability to change an activity's column or position)
2. THE Activity_Tracker SHALL allow permissions to be assigned per user or per sector, where user-level permissions take precedence over sector-level permissions when both are assigned
3. WHEN a user without View permission attempts to access the Kanban board, THE Activity_Tracker SHALL deny access, hide all board content, and display an authorization error message indicating insufficient View permission
4. WHEN a user without Create permission attempts to create an activity, THE Activity_Tracker SHALL deny the action, discard the submitted data, and display an authorization error message indicating insufficient Create permission
5. WHEN a user without Modify permission attempts to modify an activity, THE Activity_Tracker SHALL deny the action, preserve the original activity data unchanged, and display an authorization error message indicating insufficient Modify permission
6. WHEN a user without Move permission attempts to move an activity, THE Activity_Tracker SHALL deny the action, preserve the activity in its original column and position, and display an authorization error message indicating insufficient Move permission
7. IF a permission change would result in no remaining user holding all four permissions (View, Create, Modify, and Move), THEN THE Activity_Tracker SHALL reject the change and display an error message indicating that at least one user must retain full administrative permissions
8. WHEN a new user is added to the Activity_Tracker, THE Activity_Tracker SHALL assign no permissions by default until an administrator explicitly grants permissions to that user
9. WHEN an administrator revokes a permission from a user who is currently logged in, THE Activity_Tracker SHALL enforce the revoked permission no later than upon the user's next action requiring that permission, without requiring the user to log out

### Requirement 12: Cross-Platform Interface

**User Story:** As a user, I want to access the activity tracker from both desktop and mobile devices, so that I can manage activities regardless of my current device.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL provide a desktop interface that supports creating, editing, moving, and deleting activities on the Kanban board
2. THE Activity_Tracker SHALL provide a mobile interface that supports creating, editing, moving, and deleting activities on the Kanban board
3. THE Activity_Tracker SHALL synchronize activity data across all devices where the same user has an active session, such that changes appear on other devices within 5 seconds of the originating action
4. WHEN a user performs a create, edit, move, or delete action on one device, THE Activity_Tracker SHALL reflect the change on all other devices where that user has an active session within 5 seconds
5. IF the same activity is edited on two or more devices before synchronization completes, THEN THE Activity_Tracker SHALL resolve the conflict using the Democratic_Conflict_Resolution mechanism, presenting all conflicting versions to relevant responsible users and applying the version that receives majority consensus
6. WHEN a device reconnects after being offline, THE Activity_Tracker SHALL synchronize all pending changes within 10 seconds of re-establishing connectivity


### Requirement 13: Data Storage and Consistency

**User Story:** As a user, I want all application data stored using a serverless approach with democratic conflict resolution, so that the system scales without server management and data conflicts are resolved fairly through consensus.

#### Acceptance Criteria

1. THE Activity_Tracker SHALL persist all application data (users, activities, discussions, timelines, states, and access control records) using Serverless_Storage that requires no dedicated server provisioning or management
2. THE Activity_Tracker SHALL replicate all application data across a minimum of 2 geographically distributed storage nodes to ensure availability
3. THE Activity_Tracker SHALL maintain data availability of 99.9% measured on a monthly basis
4. WHEN concurrent modifications to the same activity are detected during synchronization, THE Activity_Tracker SHALL identify the Conflict and initiate the Democratic_Conflict_Resolution process within 5 seconds of detection
5. WHEN a Conflict is detected, THE Activity_Tracker SHALL present all conflicting versions to the responsible users of the affected activity, displaying the content of each version, the authoring user, and the modification timestamp
6. WHEN a Conflict is presented for resolution, THE Activity_Tracker SHALL allow each responsible user to cast one vote for the version they consider correct, within a configurable voting window that defaults to 24 hours and may be set between 1 and 72 hours
7. WHEN the voting window closes or the Consensus_Quorum is reached (whichever occurs first), THE Activity_Tracker SHALL apply the version with the most votes and discard all other conflicting versions
8. IF a voting window closes without any votes being cast, THEN THE Activity_Tracker SHALL apply the version with the most recent modification timestamp as a fallback resolution
9. IF two or more versions receive an equal number of votes, THEN THE Activity_Tracker SHALL apply the version with the most recent modification timestamp among the tied versions
10. WHILE a Conflict is pending resolution, THE Activity_Tracker SHALL display a visual indicator on the affected activity across all devices and prevent further modifications to the conflicting fields until resolution is complete
11. WHEN a Conflict is resolved, THE Activity_Tracker SHALL notify all responsible users of the affected activity within 10 seconds, indicating the resolved version and the resolution method (consensus or fallback)
12. THE Activity_Tracker SHALL log all conflict occurrences, votes cast, and resolution outcomes for audit purposes, retaining logs for a minimum of 90 days
