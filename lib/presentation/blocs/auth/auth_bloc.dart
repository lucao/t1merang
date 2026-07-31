import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_event.dart';
import 'auth_state.dart';

/// Manages authentication state for the application.
///
/// Listens to Firebase Auth state changes and handles Login, Logout, and
/// CheckAuth events. Emits [AuthLoading], [Authenticated], or
/// [Unauthenticated] states accordingly.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

  AuthBloc({firebase_auth.FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        super(const AuthLoading()) {
    on<CheckAuth>(_onCheckAuth);
    on<Login>(_onLogin);
    on<Logout>(_onLogout);
  }

  Future<void> _onCheckAuth(CheckAuth event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    await _authStateSubscription?.cancel();

    await emit.forEach<firebase_auth.User?>(
      _firebaseAuth.authStateChanges(),
      onData: (user) {
        if (user != null) {
          return Authenticated(user: user);
        }
        return const Unauthenticated();
      },
      onError: (_, __) => const Unauthenticated(
        errorMessage: 'An error occurred while checking authentication.',
      ),
    );
  }

  Future<void> _onLogin(Login event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      // The authStateChanges stream from CheckAuth will emit Authenticated.
      // If CheckAuth hasn't been dispatched yet, emit based on currentUser.
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        emit(Authenticated(user: user));
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      emit(Unauthenticated(errorMessage: _mapAuthError(e.code)));
    } catch (_) {
      emit(const Unauthenticated(errorMessage: 'Login failed. Please try again.'));
    }
  }

  Future<void> _onLogout(Logout event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      await _firebaseAuth.signOut();
      emit(const Unauthenticated());
    } catch (_) {
      emit(const Unauthenticated(errorMessage: 'Logout failed. Please try again.'));
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
