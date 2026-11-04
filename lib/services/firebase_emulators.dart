import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Explicit local-review builds use local services before any application reads.
/// Release builds keep their existing Firebase endpoints unless opted in.
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);

Future<void> configureFirebaseEmulators() async {
  if (!useFirebaseEmulators) return;
  if (!const {'localhost', '127.0.0.1', '::1'}.contains(firebaseEmulatorHost)) {
    throw StateError('Local review requires a loopback emulator host.');
  }

  await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(firebaseEmulatorHost, 9199);
}
