import 'package:fireraccoon/utils/transport_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isUnencryptedUrl', () {
    test('only a plain http scheme counts', () {
      expect(isUnencryptedUrl('http://firefly.example'), isTrue);
      expect(isUnencryptedUrl('HTTP://firefly.example'), isTrue);
      expect(isUnencryptedUrl('  http://firefly.example  '), isTrue);
      expect(isUnencryptedUrl('https://firefly.example'), isFalse);
      expect(isUnencryptedUrl(''), isFalse);
    });

    test('a local address is not treated as encrypted', () {
      // Where a host resolves says nothing about whether the bytes are
      // encrypted, and a carve-out for localhost is how a token ends up on a
      // network somebody else is on.
      expect(isUnencryptedUrl('http://localhost:8080'), isTrue);
      expect(isUnencryptedUrl('http://127.0.0.1:8080'), isTrue);
      expect(isUnencryptedUrl('http://192.168.1.10:8080'), isTrue);
    });

    test('an https host that merely mentions http is fine', () {
      expect(isUnencryptedUrl('https://http.firefly.example'), isFalse);
    });
  });

  group('requireEncryptedTransport', () {
    test('lets through an address the server is the one to dial', () {
      // The internal backend is the only address that works in a server
      // deployment, and it is exactly the address this refusal blocked. The
      // browser talks to its own origin; nothing in this process opens the
      // plain-http connection being named.
      expect(
        () => requireEncryptedTransport(
          'http://Firefly-III:8080',
          allowInsecure: false,
          dialledByServer: true,
        ),
        returnsNormally,
      );
    });

    test('still refuses it when this process does the dialling', () {
      expect(
        () => requireEncryptedTransport(
          'http://Firefly-III:8080',
          allowInsecure: false,
        ),
        throwsA(isA<InsecureTransportRefused>()),
      );
    });

    test('refuses plain http unless it was chosen', () {
      expect(
        () => requireEncryptedTransport(
          'http://firefly.example',
          allowInsecure: false,
        ),
        throwsA(isA<InsecureTransportRefused>()),
      );
    });

    test('allows plain http once it was chosen', () {
      expect(
        () => requireEncryptedTransport(
          'http://firefly.example',
          allowInsecure: true,
        ),
        returnsNormally,
      );
    });

    test('never stands in the way of https', () {
      expect(
        () => requireEncryptedTransport(
          'https://firefly.example',
          allowInsecure: false,
        ),
        returnsNormally,
      );
    });

    test('names the address it refused', () {
      // The message reaches a person who has to go and correct something, so
      // it has to say which address and what to do.
      final error = InsecureTransportRefused('http://firefly.example');
      expect('$error', contains('http://firefly.example'));
      expect('$error', contains('Allow HTTP connections'));
    });
  });
}
