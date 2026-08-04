import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../l10n/l10n_extensions.dart';
import '../providers/people_providers.dart';

/// Max edge length fed into the crop UI (keeps pan/zoom and export cheap).
const int kAvatarCropWorkingEdge = 768;

/// Validates an uploaded avatar source file. Returns an error message or null.
String? validateAvatarUploadBytes(Uint8List bytes) {
  if (bytes.length < kAvatarMinBytes) {
    return 'Image is too small (minimum 10 KB).';
  }
  if (bytes.length > kAvatarMaxBytes) {
    return 'Image is too large (maximum 5 MB).';
  }
  if (!_looksLikeRasterImage(bytes)) {
    return 'Could not read image. Use a JPG or PNG file.';
  }
  return null;
}

bool _looksLikeRasterImage(Uint8List bytes) {
  if (bytes.length < 8) return false;
  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }
  // WebP (RIFF....WEBP)
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  // Fall back to a decode for unusual but valid payloads.
  return img.decodeImage(bytes) != null;
}

/// Dialog to crop an uploaded image to a circular avatar. Saves only on confirm.
Future<Uint8List?> showAvatarCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AvatarCropDialog(imageBytes: imageBytes),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const _AvatarCropDialog({required this.imageBytes});

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  ui.Image? _image;
  String? _loadError;
  bool _saving = false;
  Size _viewport = Size.zero;

  /// Pan in viewport pixels; scale is relative to cover-fit.
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _decodeWorkingImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decodeWorkingImage() async {
    try {
      final codec = await ui.instantiateImageCodec(
        widget.imageBytes,
        targetWidth: kAvatarCropWorkingEdge,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _saving || _viewport == Size.zero) return;
    setState(() => _saving = true);
    try {
      // Let the spinner paint before export work (sync on web).
      await Future<void>.delayed(Duration.zero);
      final bytes = await _exportCircularAvatar(
        image: image,
        viewport: _viewport,
        scale: _scale,
        offset: _offset,
        outSize: kAvatarStoredEdge,
      );
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width < 520 ? size.width * 0.95 : 480.0;
    final cropSide = dialogWidth.clamp(280.0, 420.0);

    return AlertDialog(
      title: Text(l10n.cropAvatarTitle),
      content: SizedBox(
        width: dialogWidth,
        height: cropSide,
        child: _loadError != null
            ? Center(child: Text(_loadError!))
            : _image == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  _viewport = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(
                        child: GestureDetector(
                          onScaleStart: (_) {
                            _baseScale = _scale;
                            _baseOffset = _offset;
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              _scale = (_baseScale * details.scale).clamp(
                                1.0,
                                6.0,
                              );
                              _offset = _baseOffset + details.focalPointDelta;
                            });
                          },
                          child: CustomPaint(
                            painter: _AvatarImagePainter(
                              image: _image!,
                              scale: _scale,
                              offset: _offset,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      const IgnorePointer(
                        child: CustomPaint(
                          painter: _CircleCropMaskPainter(),
                          child: SizedBox.expand(),
                        ),
                      ),
                      if (_saving)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saving || _image == null ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveAvatar),
        ),
      ],
    );
  }
}

class _AvatarImagePainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;

  const _AvatarImagePainter({
    required this.image,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final placed = _coverPlacement(image, size, scale, offset);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      placed,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}

/// Semi-transparent veil outside the keep-circle, plus a white guide ring.
class _CircleCropMaskPainter extends CustomPainter {
  const _CircleCropMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addPath(circle, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(outside, Paint()..color = const Color(0x99000000));
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Rect _coverPlacement(
  ui.Image image,
  Size viewport,
  double scale,
  Offset offset,
) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final cover = math.max(viewport.width / iw, viewport.height / ih);
  final baseW = iw * cover * scale;
  final baseH = ih * cover * scale;
  final center = Offset(viewport.width / 2, viewport.height / 2);
  return Rect.fromCenter(center: center + offset, width: baseW, height: baseH);
}

/// GPU-friendly circular export via [dart:ui] (works on web without isolates).
Future<Uint8List> _exportCircularAvatar({
  required ui.Image image,
  required Size viewport,
  required double scale,
  required Offset offset,
  required int outSize,
}) async {
  final radius = math.min(viewport.width, viewport.height) / 2;
  final center = Offset(viewport.width / 2, viewport.height / 2);
  final viewRect = Rect.fromCircle(center: center, radius: radius);
  final placed = _coverPlacement(image, viewport, scale, offset);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dest = Rect.fromLTWH(0, 0, outSize.toDouble(), outSize.toDouble());

  canvas.clipPath(Path()..addOval(dest));
  final scaleToOut = outSize / (radius * 2);
  canvas.scale(scaleToOut);
  canvas.translate(-viewRect.left, -viewRect.top);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    placed,
    Paint()..filterQuality = FilterQuality.high,
  );

  final picture = recorder.endRecording();
  final outImage = await picture.toImage(outSize, outSize);
  try {
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode cropped avatar.');
    }
    return byteData.buffer.asUint8List();
  } finally {
    outImage.dispose();
  }
}
