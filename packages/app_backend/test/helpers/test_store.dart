import 'package:fireracoon_app_backend/src/crypto/sealed_store.dart';

/// PBKDF2 cost for tests.
///
/// Production derives at 210000 iterations, which takes long enough that a
/// single test opening two stores exceeded the 30 second timeout once the
/// machine was busy. The count is written into the store header and read back
/// on unlock, so a store sealed here reopens without the reader knowing this
/// number.
const int kTestPbkdf2Iterations = 1000;

Future<SealedStore> openTestStore({
  required String dataDirPath,
  required String password,
}) => SealedStore.open(
  dataDirPath: dataDirPath,
  password: password,
  iterations: kTestPbkdf2Iterations,
);
