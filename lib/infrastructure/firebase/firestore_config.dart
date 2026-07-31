import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration class that initializes Firestore with offline persistence
/// enabled for mobile and desktop platforms.
///
/// Firestore automatically handles:
/// - Offline write queue with optimistic UI updates
/// - Automatic sync on reconnection (within 10 seconds)
/// - Local cache for read operations when offline
///
/// On mobile (iOS/Android), offline persistence is enabled by default.
/// On desktop (Windows/macOS/Linux), persistence must be explicitly enabled.
class FirestoreConfig {
  final FirebaseFirestore _firestore;

  FirestoreConfig({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initializes Firestore settings with offline persistence enabled.
  ///
  /// This should be called once during app startup, before any Firestore
  /// operations are performed.
  void initialize() {
    if (_isDesktopPlatform) {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
    // On mobile (iOS/Android), persistence is enabled by default with
    // a 100 MB cache. We keep the defaults for mobile.
  }

  /// Returns the configured [FirebaseFirestore] instance.
  FirebaseFirestore get instance => _firestore;

  /// Whether the current platform is a desktop platform (Windows, macOS, Linux).
  bool get _isDesktopPlatform {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
}
