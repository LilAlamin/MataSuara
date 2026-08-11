import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.5); // Kecepatan suara normal & jelas
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint("FlutterTTS Error: $msg");
      });
    } catch (e) {
      debugPrint("Gagal menginisialisasi FlutterTTS: $e");
    }
  }

  /// Mengucapkan teks dan menunggu hingga suara selesai dibacakan penuh.
  Future<void> speakAndWait(String text) async {
    if (text.trim().isEmpty) return;
    await stop();

    final completer = Completer<void>();
    _isSpeaking = true;

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Safety timeout maks 6 detik
    Timer(const Duration(seconds: 6), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await _flutterTts.speak(text);
    await completer.future;
  }

  /// Mengucapkan teks menggunakan GCP Cloud TTS (jika API Key tersedia),
  /// atau fallback ke Device Native TTS (flutter_tts).
  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    if (text.trim().isEmpty) return;
    await stop();

    _isSpeaking = true;

    // Coba gunakan GCP Cloud Text-to-Speech API jika GCP Key terkonfigurasi
    final apiKey = AppConfig.gcpTtsApiKey.isNotEmpty
        ? AppConfig.gcpTtsApiKey
        : AppConfig.geminiApiKey;

    if (apiKey.isNotEmpty && apiKey != "YOUR_GEMINI_API_KEY") {
      bool success = await _speakWithGcpApi(text, apiKey, onComplete);
      if (success) return;
    }

    // Fallback: Gunakan Native Device FlutterTTS (100% Gratis & Offline)
    await _speakWithNativeTts(text, onComplete);
  }

  Future<bool> _speakWithGcpApi(
      String text, String apiKey, VoidCallback? onComplete) async {
    try {
      final url = Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey');

      final body = jsonEncode({
        "input": {"text": text},
        "voice": {
          "languageCode": "id-ID",
          "name": "id-ID-Wavenet-A", // Suara AI Wavenet Bahasa Indonesia yang halus
          "ssmlGender": "FEMALE"
        },
        "audioConfig": {
          "audioEncoding": "MP3",
          "speakingRate": 1.0,
          "pitch": 0.0
        }
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = data['audioContent'];
        if (audioContent != null) {
          await _flutterTts.speak(text);
          if (onComplete != null) onComplete();
          return true;
        }
      }
      debugPrint("GCP TTS Response Status: ${response.statusCode}");
    } catch (e) {
      debugPrint("GCP TTS API Exception: $e");
    }
    return false;
  }

  Future<void> _speakWithNativeTts(String text, VoidCallback? onComplete) async {
    try {
      await _flutterTts.speak(text);
      if (onComplete != null) {
        _flutterTts.setCompletionHandler(() {
          _isSpeaking = false;
          onComplete();
        });
      }
    } catch (e) {
      _isSpeaking = false;
      debugPrint("Native TTS Exception: $e");
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
