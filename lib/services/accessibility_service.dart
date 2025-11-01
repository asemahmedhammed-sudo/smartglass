// lib/services/accessibility_service.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _tts.setLanguage('ar-SA'); // Arabic language
      await _tts.setSpeechRate(0.5); // Slower for better clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize TTS: $e');
    }
  }

  /// Speak text in Arabic
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    try {
      await _tts.speak(text);
    } catch (e) {
      print('Failed to speak: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('Failed to stop TTS: $e');
    }
  }

  /// Vibration patterns for different events

  /// Short vibration for button press
  Future<void> vibrateButtonPress() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 50);
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Failed to vibrate: $e');
    }
  }

  /// Medium vibration for step completion
  Future<void> vibrateStepComplete() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 200);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Failed to vibrate: $e');
    }
  }

  /// Pattern vibration for arrival (2 short bursts)
  Future<void> vibrateArrival() async {
    try {
      if (await Vibration.hasCustomVibrationsSupport() ?? false) {
        await Vibration.vibrate(
          pattern: [0, 200, 100, 200],
          intensities: [0, 128, 0, 255],
        );
      } else if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 500);
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('Failed to vibrate: $e');
    }
  }

  /// Pattern vibration for warning (3 short bursts)
  Future<void> vibrateWarning() async {
    try {
      if (await Vibration.hasCustomVibrationsSupport() ?? false) {
        await Vibration.vibrate(
          pattern: [0, 100, 50, 100, 50, 100],
          intensities: [0, 200, 0, 200, 0, 200],
        );
      } else if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 300);
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('Failed to vibrate: $e');
    }
  }

  /// Pattern vibration for proximity alert (continuous pattern based on distance)
  Future<void> vibrateProximity(double distance) async {
    try {
      // Closer distance = stronger/faster vibration
      int duration;
      if (distance < 1.0) {
        duration = 500; // Very close - long vibration
      } else if (distance < 3.0) {
        duration = 300; // Close - medium vibration
      } else if (distance < 5.0) {
        duration = 150; // Approaching - short vibration
      } else {
        return; // Too far - no vibration
      }

      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: duration);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Failed to vibrate: $e');
    }
  }

  /// Announce distance with voice
  Future<void> announceDistance(double distance, String direction) async {
    String message;
    if (distance < 1.0) {
      message = 'أنت قريب جداً. أقل من متر واحد. $direction';
    } else if (distance < 3.0) {
      message = 'أنت قريب. ${distance.toStringAsFixed(1)} متر. $direction';
    } else if (distance < 5.0) {
      message = '${distance.toStringAsFixed(1)} متر. $direction';
    } else {
      message = '${distance.toStringAsFixed(0)} متر. $direction';
    }
    await speak(message);
  }

  /// Announce step with event description
  Future<void> announceStep(int stepNumber, String? eventDescription, int totalSteps) async {
    String message = 'الخطوة $stepNumber من $totalSteps. ';
    if (eventDescription != null && eventDescription.isNotEmpty) {
      message += eventDescription;
    } else {
      message += 'استمر في المسار';
    }
    await speak(message);
  }

  /// Announce arrival
  Future<void> announceArrival(String destinationName) async {
    await speak('تهانينا! لقد وصلت إلى $destinationName');
    await vibrateArrival();
  }

  /// Announce new path created
  Future<void> announcePathCreated() async {
    await speak('تم حفظ المسار بنجاح');
    await vibrateStepComplete();
  }

  /// Announce step added
  Future<void> announceStepAdded(int stepNumber) async {
    await speak('تمت إضافة الخطوة رقم $stepNumber');
    await vibrateStepComplete();
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('Failed to dispose TTS: $e');
    }
  }
}