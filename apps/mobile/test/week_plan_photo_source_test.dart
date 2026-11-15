import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/week_plan_photo_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalization keeps pixels and drops non-pixel PNG metadata', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAHnRFWHRDb21tZW50AG1ldGFkYXRhLXRlc3Qtc2VudGluZWwqaJLIAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
    );
    final normalized = await WeekPlanPhotoSource.normalize(png);
    expect(normalized.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(
      latin1.decode(normalized),
      isNot(contains('metadata-test-sentinel')),
    );
  });

  test('oversized input is rejected before image decoding', () async {
    await expectLater(
      WeekPlanPhotoSource.normalize(Uint8List(20 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
  });

  test('detailed local photos above 4 MB remain usable', () async {
    const size = 1300;
    final random = Random(42);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = random.nextInt(256);
      pixels[i + 1] = random.nextInt(256);
      pixels[i + 2] = random.nextInt(256);
      pixels[i + 3] = 255;
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    final image = await decoded.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final photo = data!.buffer.asUint8List();
    expect(photo.length, greaterThan(4 * 1024 * 1024));
    final normalized = await WeekPlanPhotoSource.normalize(photo);
    expect(normalized.length, greaterThan(4 * 1024 * 1024));
    expect(normalized.length, lessThanOrEqualTo(16 * 1024 * 1024));
  });
}
