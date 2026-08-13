import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum ScanMode { scan, navigation }

class GeminiService {
  /// Mengirim gambar ke Gemini AI Multimodal Vision menggunakan HTTP REST API
  Future<String> analyzeImage({
    required Uint8List imageBytes,
    required ScanMode mode,
    String? userQuestion,
  }) async {
    final apiKey = AppConfig.geminiApiKey.isNotEmpty
        ? AppConfig.geminiApiKey
        : AppConfig.gcpTtsApiKey;

    if (apiKey.isEmpty || apiKey == "YOUR_GEMINI_API_KEY") {
      return _generateDemoResponse(mode, userQuestion);
    }

    final promptText = _getPromptForMode(mode, userQuestion);

    // Daftar model Gemini AI yang dicoba
    final candidateModels = [
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-flash-latest',
      'gemini-3.1-flash-lite',
    ];

    List<Map<String, dynamic>> parts = [
      {"text": promptText}
    ];

    if (imageBytes.isNotEmpty) {
      parts.add({
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": base64Encode(imageBytes)
        }
      });
    }

    final bodyJson = jsonEncode({
      "contents": [
        {"parts": parts}
      ]
    });

    String lastError = "";

    for (final model in candidateModels) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: bodyJson,
        );

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final candidates = resData['candidates'];
          if (candidates != null && candidates.isNotEmpty) {
            final partsList = candidates[0]['content']['parts'];
            if (partsList != null && partsList.isNotEmpty) {
              final String resultText = partsList[0]['text'];
              debugPrint("Gemini HTTP Berhasil dengan model: $model");
              return resultText.trim();
            }
          }
        } else {
          final resData = jsonDecode(response.body);
          final errMessage = resData['error']?['message'] ?? response.body;
          final errReason = resData['error']?['details']?[0]?['reason'] ?? "";
          debugPrint("GCP Gemini HTTP Error ($model): $errMessage");
          if (errMessage.toLowerCase().contains("leaked") || errReason == "API_KEY_SERVICE_BLOCKED" || response.statusCode == 403) {
            return "API Key Gemini dilaporkan bocor atau diblokir. Harap gunakan API Key baru dari aistudio.google.com";
          }
          if (response.statusCode == 429) {
            return "Kredit/Kuota API Key Gemini pada akun ini telah habis (RESOURCE_EXHAUSTED). Harap buat API Key baru di akun Google AI Studio lain atau isi saldo di ai.studio.";
          }
          lastError = "[$model] $errMessage";
        }
      } catch (e) {
        debugPrint("Gemini HTTP Exception ($model): $e");
        lastError = e.toString();
      }
    }

    return "Gagal memproses AI: $lastError";
  }

  String _getPromptForMode(ScanMode mode, String? userQuestion) {
    switch (mode) {
      case ScanMode.scan:
        if (userQuestion != null && userQuestion.isNotEmpty) {
          return "Anda adalah asisten AI ramah untuk disabilitas netra. "
              "Jawab pertanyaan pengguna berikut berdasarkan gambar yang diberikan secara singkat dan akurat dalam Bahasa Indonesia. "
              "Pertanyaan Pengguna: '$userQuestion'";
        }
        return "Anda adalah asisten suara pintar untuk disabilitas netra. "
            "Analisis gambar di depan pengguna: sebutkan benda utama, baca teks yang ada, atau kenali nominal uang rupiah yang terlihat secara serentak dalam 1-2 kalimat ringkas, padat, dan jelas dalam Bahasa Indonesia.";

      case ScanMode.navigation:
        return "Anda adalah asisten petunjuk arah jalan dan navigasi untuk pengguna disabilitas netra. "
            "Berikan petunjuk arah dan posisi halangan/ruangan secara presisi dalam 1-2 kalimat Bahasa Indonesia. "
            "Contoh format: 'Di depan Anda jalan aman lurus, di sebelah kanan ada meja berjarak 1 meter. Tidak ada halangan berbahaya'.";
    }
  }

  /// Simulasi respon cepat jika API key belum diisi oleh developer
  String _generateDemoResponse(ScanMode mode, String? userQuestion) {
    switch (mode) {
      case ScanMode.scan:
        return "Di depan Anda terdapat cangkir kopi putih dan teks 'Pintu Keluar' berjarak 1 meter.";
      case ScanMode.navigation:
        return "Di depan Anda terdapat jalur lurus aman berjarak 2 meter. Di sebelah kanan ada kursi kayu.";
    }
  }
}
