package com.example.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kondate/week_plan_text")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.size > 4 * 1024 * 1024) {
                    result.error("invalid_photo", "Bitte ein kleineres Foto auswählen.", null)
                    return@setMethodCallHandler
                }
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                if (bounds.outWidth !in 1..2000 || bounds.outHeight !in 1..2000) {
                    result.error("invalid_photo", "Foto konnte nicht gelesen werden.", null)
                    return@setMethodCallHandler
                }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    result.error("invalid_photo", "Foto konnte nicht gelesen werden.", null)
                    return@setMethodCallHandler
                }
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                recognizer.process(InputImage.fromBitmap(bitmap, 0))
                    .addOnSuccessListener { text ->
                        val lines = text.textBlocks.flatMap { it.lines }.take(500).mapNotNull { line ->
                            line.boundingBox?.let { box ->
                                mapOf("text" to line.text,
                                    "x" to (box.left.toDouble() / bitmap.width).coerceIn(0.0, 1.0),
                                    "y" to (box.top.toDouble() / bitmap.height).coerceIn(0.0, 1.0),
                                    "width" to (box.width().toDouble() / bitmap.width).coerceIn(0.0, 1.0),
                                    "height" to (box.height().toDouble() / bitmap.height).coerceIn(0.0, 1.0))
                            }
                        }
                        result.success(lines)
                    }
                    .addOnFailureListener {
                        result.error("recognition_failed",
                            "Text konnte auf diesem Gerät nicht gelesen werden. Bitte ein schärferes Foto wählen oder die Mahlzeiten unten eintragen.", null)
                    }
                    .addOnCompleteListener {
                        recognizer.close()
                        bitmap.recycle()
                    }
            }
    }
}
