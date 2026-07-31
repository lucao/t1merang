import 'package:equatable/equatable.dart';

/// Events that can be dispatched to the [AuthBloc].
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the user initiates a login with email and password.
class Login extends AuthEvent {
  final String email;
  final String password;

  const Login({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Triggered when the user logs out.
class Logout extends AuthEvent {
  const Logout();
}

/// Triggered on app startup to check if a user session already exists.
class CheckAuth extends AuthEvent {
  const CheckAuth();
}
