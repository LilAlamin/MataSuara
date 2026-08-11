import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum ScanMode { objectScene, textReader, currency, voiceQuery }

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
          if (errReason == "API_KEY_SERVICE_BLOCKED" || response.statusCode == 403) {
            return "API Key Gemini belum diizinkan untuk Generative Language API. Dapatkan API Key gratis di aistudio.google.com";
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
      case ScanMode.objectScene:
        return "Anda adalah asisten suara terbaik untuk pengguna disabilitas netra. "
            "Jelaskan benda utama dan posisi/jaraknya dalam gambar ini dalam 1-2 kalimat ringkas, padat, dan jelas dalam Bahasa Indonesia. "
            "Contoh format: 'Di depan Anda ada [benda] di atas [lokasi] berjarak sekitar [perkiraan jarak]'.";

      case ScanMode.textReader:
        return "Anda adalah asisten pembaca teks untuk pengguna disabilitas netra. "
            "Bacakan seluruh teks atau tulisan yang tertera pada gambar ini secara akurat dan urut dalam Bahasa Indonesia. "
            "Jika tidak ada teks, katakan 'Tidak ditemukan teks pada gambar ini'.";

      case ScanMode.currency:
        return "Anda adalah asisten pengenal uang kertas rupiah untuk disabilitas netra. "
            "Sebutkan nilai nominal uang kertas Rupiah (IDR) yang ada di dalam gambar ini secara tegas dan singkat. "
            "Contoh: 'Terdeteksi uang kertas lima puluh ribu rupiah'. Jika tidak jelas, sebutkan uang tidak terdeteksi.";

      case ScanMode.voiceQuery:
        return "Anda adalah asisten AI ramah untuk disabilitas netra. "
            "Jawab pertanyaan pengguna berikut berdasarkan gambar yang diberikan secara singkat dan akurat dalam Bahasa Indonesia. "
            "Pertanyaan Pengguna: '${userQuestion ?? 'Apa yang ada di gambar ini?'}'";
    }
  }

  /// Simulasi respon cepat jika API key belum diisi oleh developer
  String _generateDemoResponse(ScanMode mode, String? userQuestion) {
    switch (mode) {
      case ScanMode.objectScene:
        return "Di depan Anda terdapat cangkir kopi putih di atas meja kayu berjarak sekitar 1 meter.";
      case ScanMode.textReader:
        return "Teks terdeteksi: Pintu Keluar Darurat. Harap menjaga ketertiban.";
      case ScanMode.currency:
        return "Terdeteksi uang kertas lima puluh ribu rupiah.";
      case ScanMode.voiceQuery:
        return "Berdasarkan gambar, benda di depan Anda adalah botol air mineral.";
    }
  }
}
