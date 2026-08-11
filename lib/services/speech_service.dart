import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint("STT Status: $status");
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (errorNotification) {
          debugPrint("STT Error: ${errorNotification.errorMsg}");
          _isListening = false;
        },
      );
    } catch (e) {
      debugPrint("STT Init Exception: $e");
      _isAvailable = false;
    }
    return _isAvailable;
  }

  Future<void> listen({
    required Function(String text) onResult,
    required VoidCallback onListeningComplete,
  }) async {
    if (!_isAvailable) {
      bool available = await init();
      if (!available) {
        onResult("Fitur perintah suara tidak tersedia di perangkat ini.");
        onListeningComplete();
        return;
      }
    }

    _isListening = true;
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          _isListening = false;
          onListeningComplete();
        }
      },
    );
  }

  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }
}
