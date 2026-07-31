import 'package:equatable/equatable.dart';

import '../../../domain/entities/conflict.dart';

/// States emitted by the [ConflictBloc].
abstract class ConflictState extends Equatable {
  const ConflictState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any conflicts are loaded.
class ConflictIdle extends ConflictState {
  const ConflictIdle();
}

/// State while conflicts are being fetched.
class ConflictLoading extends ConflictState {
  const ConflictLoading();
}

/// State when active conflicts have been loaded successfully.
class ConflictLoaded extends ConflictState {
  final List<Conflict> conflicts;

  const ConflictLoaded({required this.conflicts});

  @override
  List<Object?> get props => [conflicts];
}

/// State when an error occurred while loading or acting on conflicts.
class ConflictError extends ConflictState {
  final String message;

  const ConflictError({required this.message});

  @override
  List<Object?> get props => [message];
}
