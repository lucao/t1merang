import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// States emitted by the [AuthBloc].
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// The initial/loading state while authentication status is being determined.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The user is authenticated. Holds a reference to the Firebase user.
class Authenticated extends AuthState {
  final firebase_auth.User user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user.uid];
}

/// The user is not authenticated.
class Unauthenticated extends AuthState {
  final String? errorMessage;

  const Unauthenticated({this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
