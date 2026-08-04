import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/widgets/avatar_crop_dialog.dart';
import 'package:image/image.dart' as img;

Uint8List _pngOfSize(int edge, {int minBytes = 0}) {
  final image = img.Image(width: edge, height: edge);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  var bytes = Uint8List.fromList(img.encodePng(image));
  if (bytes.length >= minBytes) return bytes;
  // Pad with a comment chunk–safe approach: grow canvas until big enough.
  var grow = edge;
  while (bytes.length < minBytes) {
    grow += 64;
    final bigger = img.Image(width: grow, height: grow);
    img.fill(bigger, color: img.ColorRgb8(40, 120, 200));
    // Noise so PNG doesn't compress too small.
    for (var i = 0; i < grow; i += 3) {
      bigger.setPixelRgb(i % grow, (i * 7) % grow, i % 255, 100, 50);
    }
    bytes = Uint8List.fromList(img.encodePng(bigger));
  }
  return bytes;
}

void main() {
  test('rejects uploads under 10 KB', () {
    final bytes = Uint8List(kAvatarMinBytes - 1);
    expect(validateAvatarUploadBytes(bytes), contains('10 KB'));
  });

  test('rejects uploads over 5 MB', () {
    final bytes = Uint8List(kAvatarMaxBytes + 1);
    expect(validateAvatarUploadBytes(bytes), contains('5 MB'));
  });

  test('rejects undecodable image bytes in range', () {
    final bytes = Uint8List(kAvatarMinBytes);
    expect(validateAvatarUploadBytes(bytes), contains('JPG or PNG'));
  });

  test('accepts a valid PNG large enough for upload', () {
    final bytes = _pngOfSize(256, minBytes: kAvatarMinBytes);
    expect(bytes.length, greaterThanOrEqualTo(kAvatarMinBytes));
    expect(validateAvatarUploadBytes(bytes), isNull);
  });

  test('normalizeAvatarPng downscales large images to 256', () {
    final large = _pngOfSize(512);
    final normalized = normalizeAvatarPng(large);
    final decoded = img.decodeImage(normalized);
    expect(decoded, isNotNull);
    expect(decoded!.width, kAvatarStoredEdge);
    expect(decoded.height, kAvatarStoredEdge);
  });
}
