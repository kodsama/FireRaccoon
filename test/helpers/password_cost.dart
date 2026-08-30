import 'package:fireraccoon/utils/password_policy.dart';

/// PBKDF2 cost for tests.
///
/// Production derives at [kPbkdf2Iterations], which is deliberately expensive:
/// a single hash takes seconds. A suite that pays it for every password it sets
/// spends minutes deriving keys and starts failing on the clock rather than on
/// anything it asserts. The count is recorded in the hash, so one made here
/// verifies at the count that made it and the code under test never knows.
const int kTestPbkdf2Iterations = 1000;

/// [hashPassword] at a cost a test can afford.
Future<PasswordHash> hashTestPassword(String password, {String? saltBase64}) =>
    hashPassword(
      password,
      saltBase64: saltBase64,
      iterations: kTestPbkdf2Iterations,
    );
