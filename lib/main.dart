import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'firebase_options.dart';

import 'data/repositories/firestore_access_control_repository.dart';
import 'data/repositories/firestore_activity_repository.dart';
import 'data/repositories/firestore_conflict_repository.dart';
import 'data/repositories/firestore_discussion_repository.dart';
import 'data/repositories/firestore_notification_repository.dart';
import 'data/repositories/firestore_state_repository.dart';
import 'domain/use_cases/cast_vote_use_case.dart';
import 'domain/use_cases/group_activities_by_state.dart';
import 'domain/use_cases/move_activity_use_case.dart';
import 'infrastructure/firebase/firestore_config.dart';
import 'infrastructure/services/connectivity_service.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
import 'presentation/blocs/conflict/conflict_bloc.dart';
import 'presentation/blocs/kanban/kanban_bloc.dart';
import 'presentation/blocs/kanban/kanban_event.dart';
import 'presentation/blocs/kanban/kanban_state.dart';
import 'presentation/pages/kanban_board_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence for desktop platforms
  FirestoreConfig().initialize();

  runApp(const ActivityTrackerApp());
}

class ActivityTrackerApp extends StatefulWidget {
  const ActivityTrackerApp({super.key});

  @override
  State<ActivityTrackerApp> createState() => _ActivityTrackerAppState();
}

class _ActivityTrackerAppState extends State<ActivityTrackerApp> {
  // Repositories (created once, shared across the app)
  late final FirestoreActivityRepository _activityRepo;
  late final FirestoreStateRepository _stateRepo;
  late final FirestoreAccessControlRepository _accessControlRepo;
  late final FirestoreConflictRepository _conflictRepo;
  late final FirestoreDiscussionRepository _discussionRepo;
  late final FirestoreNotificationRepository _notificationRepo;

  // Services
  late final ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _activityRepo = FirestoreActivityRepository();
    _stateRepo = FirestoreStateRepository();
    _accessControlRepo = FirestoreAccessControlRepository();
    _conflictRepo = FirestoreConflictRepository();
    _discussionRepo = FirestoreDiscussionRepository();
    _notificationRepo = FirestoreNotificationRepository();

    _connectivityService = ConnectivityService()..startMonitoring();
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc()..add(const CheckAuth()),
        ),
        BlocProvider(
          create: (_) => KanbanBloc(
            activityRepository: _activityRepo,
            stateRepository: _stateRepo,
            accessControlRepository: _accessControlRepo,
            moveActivityUseCase: MoveActivityUseCase(
              activityRepository: _activityRepo,
              accessControlRepository: _accessControlRepo,
              notificationRepository: _notificationRepo,
            ),
            groupActivitiesByState: const GroupActivitiesByState(),
          ),
        ),
        BlocProvider(
          create: (_) => ConflictBloc(
            conflictRepository: _conflictRepo,
            castVoteUseCase: CastVoteUseCase(
              conflictRepository: _conflictRepo,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Activity Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (state is Authenticated) {
              return _AuthenticatedHome(
                userId: state.user.uid,
                connectivityService: _connectivityService,
                activityRepo: _activityRepo,
                discussionRepo: _discussionRepo,
                accessControlRepo: _accessControlRepo,
                notificationRepo: _notificationRepo,
              );
            }
            return _LoginPage(
              errorMessage:
                  state is Unauthenticated ? state.errorMessage : null,
            );
          },
        ),
      ),
    );
  }
}

/// The main authenticated view — loads the Kanban board with connectivity awareness.
class _AuthenticatedHome extends StatelessWidget {
  final String userId;
  final ConnectivityService connectivityService;
  final FirestoreActivityRepository activityRepo;
  final FirestoreDiscussionRepository discussionRepo;
  final FirestoreAccessControlRepository accessControlRepo;
  final FirestoreNotificationRepository notificationRepo;

  const _AuthenticatedHome({
    required this.userId,
    required this.connectivityService,
    required this.activityRepo,
    required this.discussionRepo,
    required this.accessControlRepo,
    required this.notificationRepo,
  });

  @override
  Widget build(BuildContext context) {
    // Load the board on first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kanbanBloc = context.read<KanbanBloc>();
      if (kanbanBloc.state is! KanbanLoaded) {
        // Default to the user's sector — for now use a placeholder
        kanbanBloc.add(const LoadBoard(sectorId: 'Engineering'));
      }
    });

    return StreamBuilder<ConnectivityStatus>(
      stream: connectivityService.statusStream,
      initialData: connectivityService.currentStatus,
      builder: (context, connectivitySnapshot) {
        return StreamBuilder<bool>(
          stream: connectivityService.syncingStream,
          initialData: connectivityService.isSyncing,
          builder: (context, syncSnapshot) {
            final isOffline =
                connectivitySnapshot.data == ConnectivityStatus.offline;
            final isSyncing = syncSnapshot.data ?? false;

            return KanbanBoardPage(
              availableSectors: const [
                'Engineering',
                'Design',
                'Marketing',
                'Sales',
                'Support',
              ],
              currentUserId: userId,
              isOffline: isOffline,
              isSyncing: isSyncing,
            );
          },
        );
      },
    );
  }
}

/// A simple login page with email/password fields.
class _LoginPage extends StatefulWidget {
  final String? errorMessage;

  const _LoginPage({this.errorMessage});

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            Login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.view_kanban_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activity Tracker',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (widget.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
