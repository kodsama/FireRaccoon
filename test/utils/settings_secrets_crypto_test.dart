import 'dart:convert';

import 'package:fireracoon/utils/settings_secrets_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seal and unseal round-trip', () async {
    final envelope = await SettingsSecretsCrypto.seal(
      plaintext: {
        'apiToken': 'ff-token-secret',
        'peopleAuth': {
          'p1': {'passwordHash': 'hash', 'salt': 'salt'},
        },
      },
      passphrase: 'Correct-Horse9!',
    );

    expect(envelope['v'], 1);
    expect(envelope['ciphertext'], isNotEmpty);
    expect(envelope.values.join(), isNot(contains('ff-token-secret')));

    final clear = await SettingsSecretsCrypto.unseal(
      envelope: envelope,
      passphrase: 'Correct-Horse9!',
    );
    expect(clear['apiToken'], 'ff-token-secret');
    expect((clear['peopleAuth'] as Map)['p1']['salt'], 'salt');
  });

  test('wrong passphrase throws unlock exception', () async {
    final envelope = await SettingsSecretsCrypto.seal(
      plaintext: {'apiToken': 'x'},
      passphrase: 'Correct-Horse9!',
    );
    await expectLater(
      () => SettingsSecretsCrypto.unseal(
        envelope: envelope,
        passphrase: 'Wrong-Horse9!',
      ),
      throwsA(isA<SettingsSecretsUnlockException>()),
    );
  });

  test('empty passphrase is rejected for seal and unseal', () async {
    expect(
      () => SettingsSecretsCrypto.seal(plaintext: {'a': 1}, passphrase: ''),
      throwsArgumentError,
    );
    await expectLater(
      () => SettingsSecretsCrypto.unseal(
        envelope: {
          'v': 1,
          'salt': base64Encode(List<int>.filled(16, 1)),
          'nonce': base64Encode(List<int>.filled(12, 2)),
          'mac': base64Encode(List<int>.filled(16, 3)),
          'ciphertext': base64Encode(List<int>.filled(8, 4)),
        },
        passphrase: '',
      ),
      throwsA(
        isA<SettingsSecretsUnlockException>().having(
          (e) => e.toString(),
          'message',
          contains('required'),
        ),
      ),
    );
  });

  test('unsupported secrets version is rejected', () async {
    await expectLater(
      () => SettingsSecretsCrypto.unseal(
        envelope: {
          'v': 99,
          'salt': base64Encode(List<int>.filled(16, 1)),
          'nonce': base64Encode(List<int>.filled(12, 2)),
          'mac': base64Encode(List<int>.filled(16, 3)),
          'ciphertext': base64Encode(List<int>.filled(8, 4)),
        },
        passphrase: 'Correct-Horse9!',
      ),
      throwsFormatException,
    );
  });
}
