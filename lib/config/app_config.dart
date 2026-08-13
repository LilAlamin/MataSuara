import 'package:flutter/material.dart';

class AppConfig {
  // API Key Gemini & GCP TTS
  // Dapat diisi via --dart-define=GEMINI_API_KEY=xxx saat run/build
  // Atau diisi secara lokal (JANGAN DIPUSH / COMMIT KE GITHUB!)
  static String geminiApiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String gcpTtsApiKey = const String.fromEnvironment(
    'GCP_TTS_API_KEY',
    defaultValue: '',
  );

  static const String appName = "MataSuara";
  static const String appTagline = "Scanner & Asisten Suara Disabilitas Netra";
}

class AppColors {
  // Palette Warna Light Mode Kontras Tinggi (WCAG AAA Compliant)
  static const Color background = Color(0xFFF8FAFC); // Off-White
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color primaryBlue = Color(0xFF1D4ED8); // Royal Blue
  static const Color secondaryEmerald = Color(0xFF059669); // Emerald Green
  static const Color textDark = Color(0xFF0F172A); // Dark Slate Teks
  static const Color textSubtle = Color(0xFF475569); // Slate Grey
  static const Color borderLight = Color(0xFFE2E8F0);
  
  // Status & Mode Colors
  static const Color modeObject = Color(0xFF2563EB); // Vibrant Blue
  static const Color modeText = Color(0xFFD97706); // Amber
  static const Color modeCurrency = Color(0xFF10B981); // Emerald
  static const Color modeVoice = Color(0xFF8B5CF6); // Purple
  
  static const Color speakActive = Color(0xFFDC2626); // Crimson Red saat AI bicara

  // iOS Human Interface Guidelines (HIG) Native Color Tokens
  static const Color iosBackground = Color(0xFFF2F2F7); // iOS System Grouped Background
  static const Color iosSecondaryBackground = Color(0xFFFFFFFF);
  static const Color iosSystemBlue = Color(0xFF007AFF); // Apple System Blue
  static const Color iosSystemIndigo = Color(0xFF5856D6);
  static const Color iosSystemGreen = Color(0xFF34C759);
  static const Color iosSystemRed = Color(0xFFFF3B30);
  static const Color iosSystemGray = Color(0xFF8E8E93);
  static const Color iosSystemGray5 = Color(0xFFE5E5EA);
  static const Color iosSystemGray6 = Color(0xFFF2F2F7);
  static const Color iosTranslucentHeader = Color(0xCCF9F9F9); // Frosted Glass Header
}
