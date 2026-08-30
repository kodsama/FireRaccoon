import 'package:fireraccoon_app_backend/fireraccoon_app_backend.dart';

/// PBKDF2 cost for tests.
///
/// Production derives at 210000 iterations, which takes long enough that a
/// single test opening two stores exceeded the 30 second timeout once the
/// machine was busy. The count is written into the store header and read back
/// on unlock, so a store sealed here reopens without the reader knowing this
/// number.
const int kTestPbkdf2Iterations = 1000;

/// A server whose derivations cost what a test can afford.
///
/// Production hashes a password at 600k rounds and opens a store at 210k. A
/// suite that pays either for every case spends minutes deriving keys and
/// starts failing on the clock rather than on anything it asserts. Both counts
/// are recorded in what they produce, so a store sealed here reopens and a
/// password set here verifies without the reader knowing this number.
Future<AppServer> openTestServer(ServerConfig config) => AppServer.open(
  config,
  passwordIterations: kTestPbkdf2Iterations,
  storeIterations: kTestPbkdf2Iterations,
);

Future<SealedStore> openTestStore({
  required String dataDirPath,
  required String password,
}) => SealedStore.open(
  dataDirPath: dataDirPath,
  password: password,
  iterations: kTestPbkdf2Iterations,
);
