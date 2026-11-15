import 'dart:convert';
import 'dart:typed_data';

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
}
