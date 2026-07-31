import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:activity_tracker/presentation/blocs/auth/auth_bloc.dart';
import 'package:activity_tracker/presentation/blocs/auth/auth_event.dart';
import 'package:activity_tracker/presentation/blocs/auth/auth_state.dart';

// --- Mocks ---

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class MockUser extends Mock implements firebase_auth.User {}

class MockUserCredential extends Mock
    implements firebase_auth.UserCredential {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    when(() => mockUser.uid).thenReturn('user-123');
  });

  group('AuthBloc', () {
    group('CheckAuth', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Authenticated] when user is logged in',
        build: () {
          when(() => mockFirebaseAuth.authStateChanges())
              .thenAnswer((_) => Stream.value(mockUser));
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(const CheckAuth()),
        expect: () => [
          const AuthLoading(),
          isA<Authenticated>(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated] when no user is logged in',
        build: () {
          when(() => mockFirebaseAuth.authStateChanges())
              .thenAnswer((_) => Stream.value(null));
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(const CheckAuth()),
        expect: () => [
          const AuthLoading(),
          const Unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated(error)] when stream errors',
        build: () {
          when(() => mockFirebaseAuth.authStateChanges())
              .thenAnswer((_) => Stream.error(Exception('auth error')));
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(const CheckAuth()),
        expect: () => [
          const AuthLoading(),
          isA<Unauthenticated>().having(
            (s) => s.errorMessage,
            'errorMessage',
            isNotNull,
          ),
        ],
      );
    });

    group('Login', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Authenticated] on successful login',
        build: () {
          final credential = MockUserCredential();
          when(() => mockFirebaseAuth.signInWithEmailAndPassword(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer((_) async => credential);
          when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(
          const Login(email: 'test@example.com', password: 'password123'),
        ),
        expect: () => [
          const AuthLoading(),
          isA<Authenticated>(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated(error)] on FirebaseAuthException',
        build: () {
          when(() => mockFirebaseAuth.signInWithEmailAndPassword(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(
            firebase_auth.FirebaseAuthException(
              code: 'wrong-password',
              message: 'Wrong password',
            ),
          );
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(
          const Login(email: 'test@example.com', password: 'wrong'),
        ),
        expect: () => [
          const AuthLoading(),
          isA<Unauthenticated>().having(
            (s) => s.errorMessage,
            'errorMessage',
            contains('Incorrect password'),
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated(error)] on generic exception',
        build: () {
          when(() => mockFirebaseAuth.signInWithEmailAndPassword(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(Exception('unexpected'));
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(
          const Login(email: 'test@example.com', password: 'pass'),
        ),
        expect: () => [
          const AuthLoading(),
          isA<Unauthenticated>().having(
            (s) => s.errorMessage,
            'errorMessage',
            'Login failed. Please try again.',
          ),
        ],
      );
    });

    group('Logout', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated] on successful logout',
        build: () {
          when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(const Logout()),
        expect: () => [
          const AuthLoading(),
          const Unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, Unauthenticated(error)] when signOut fails',
        build: () {
          when(() => mockFirebaseAuth.signOut())
              .thenThrow(Exception('signout failed'));
          return AuthBloc(firebaseAuth: mockFirebaseAuth);
        },
        act: (bloc) => bloc.add(const Logout()),
        expect: () => [
          const AuthLoading(),
          isA<Unauthenticated>().having(
            (s) => s.errorMessage,
            'errorMessage',
            'Logout failed. Please try again.',
          ),
        ],
      );
    });
  });
}
