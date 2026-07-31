import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the current connectivity state of the application.
enum ConnectivityStatus {
  /// The device is online and connected to Firestore.
  online,

  /// The device is offline; reads come from cache and writes are queued.
  offline,
}

/// A service that monitors network connectivity state and exposes a stream
/// of online/offline status.
///
/// Uses Firestore's built-in network management (`enableNetwork` /
/// `disableNetwork`) and snapshot listener metadata to detect connectivity
/// changes. Firestore automatically handles:
/// - Queuing writes while offline (optimistic UI updates)
/// - Syncing pending writes on reconnection (within 10 seconds)
///
/// The service also tracks whether there are pending writes that have not
/// yet been confirmed by the server (the "syncing" state).
class ConnectivityService {
  final FirebaseFirestore _firestore;

  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  final StreamController<bool> _syncingController =
      StreamController<bool>.broadcast();

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  bool _isSyncing = false;
  StreamSubscription<QuerySnapshot>? _snapshotSubscription;

  ConnectivityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// A broadcast stream that emits the current [ConnectivityStatus] whenever
  /// it changes.
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// A broadcast stream that emits `true` when there are pending writes
  /// syncing, and `false` when all writes are confirmed.
  Stream<bool> get syncingStream => _syncingController.stream;

  /// The current connectivity status.
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Whether there are pending writes that haven't been confirmed by the server.
  bool get isSyncing => _isSyncing;

  /// Whether the device is currently online.
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  /// Whether the device is currently offline.
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  /// Starts monitoring connectivity by listening to Firestore snapshot metadata.
  ///
  /// Uses a lightweight query on a known collection to detect connectivity
  /// changes through the `isFromCache` metadata property.
  ///
  /// [collectionPath] - The Firestore collection to monitor. Defaults to
  /// 'activities' as it's a commonly accessed collection.
  void startMonitoring({String collectionPath = 'activities'}) {
    _snapshotSubscription = _firestore
        .collection(collectionPath)
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        final isFromCache = snapshot.metadata.isFromCache;
        final hasPendingWrites = snapshot.metadata.hasPendingWrites;

        // Update connectivity status
        final newStatus = isFromCache
            ? ConnectivityStatus.offline
            : ConnectivityStatus.online;

        if (newStatus != _currentStatus) {
          _currentStatus = newStatus;
          _statusController.add(_currentStatus);
        }

        // Update syncing status
        if (hasPendingWrites != _isSyncing) {
          _isSyncing = hasPendingWrites;
          _syncingController.add(_isSyncing);
        }
      },
      onError: (error) {
        // On error, assume offline
        if (_currentStatus != ConnectivityStatus.offline) {
          _currentStatus = ConnectivityStatus.offline;
          _statusController.add(_currentStatus);
        }
      },
    );
  }

  /// Manually disables the network connection for Firestore.
  ///
  /// Useful for testing offline behavior or when the app detects
  /// poor connectivity and wants to switch to offline mode proactively.
  Future<void> goOffline() async {
    await _firestore.disableNetwork();
    _currentStatus = ConnectivityStatus.offline;
    _statusController.add(_currentStatus);
  }

  /// Manually re-enables the network connection for Firestore.
  ///
  /// Firestore will automatically sync all pending writes within 10 seconds
  /// of reconnection.
  Future<void> goOnline() async {
    await _firestore.enableNetwork();
    // The actual status update will come through the snapshot listener
    // when the connection is re-established.
  }

  /// Disposes of all resources used by this service.
  Future<void> dispose() async {
    await _snapshotSubscription?.cancel();
    await _statusController.close();
    await _syncingController.close();
  }
}
