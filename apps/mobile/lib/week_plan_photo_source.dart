import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Photos stay on the device. Normalize orientation/size and omit metadata
/// before passing pixels to the local text recognizer.
class WeekPlanPhotoSource {
  final ImagePicker _picker = ImagePicker();
  static const _camera = MethodChannel('kondate/week_plan_camera');

  Future<void> cancel() async {
    if (Platform.isMacOS) {
      try {
        await _camera.invokeMethod<void>('cancel');
      } on PlatformException {
        // Closing the review must remain possible if the native view has gone.
      } on MissingPluginException {
        // Unit tests do not load the native camera channel.
      }
    }
  }

  Future<Uint8List?> pick({required bool camera}) async {
    if (camera && Platform.isMacOS) {
      final bytes = await _camera.invokeMethod<Uint8List>('capture');
      return bytes == null ? null : normalize(bytes);
    }
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file == null ? null : _read(file);
  }

  Future<Uint8List?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    return files == null || files.isEmpty ? null : _read(files.first);
  }

  Future<Uint8List> _read(XFile file) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('Das Foto ist zu gross (maximal 20 MB).');
    }
    return normalize(await file.readAsBytes());
  }

  static Future<Uint8List> normalize(Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Das Foto ist zu gross (maximal 20 MB).');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest > 2000 ? 2000 / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 2000),
        targetHeight: (descriptor.height * scale).round().clamp(1, 2000),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      // At most 2000 × 2000 pixels. PNG can approach the raw RGBA size for
      // textured photos; a cloud-upload-sized 4 MB cap rejects valid captures.
      if (data == null || data.lengthInBytes > 16 * 1024 * 1024) {
        throw const FormatException(
          'Bitte ein kleineres Foto oder einen engeren Ausschnitt wählen.',
        );
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
