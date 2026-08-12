import 'package:flutter/material.dart';

class AppConfig {
  // Masukkan API Key Gemini / GCP di sini
  static String geminiApiKey = "AIzaSyA63c6kP8PtNHGXUMa1O_MI8JjVxK_PQjM";
  static String gcpTtsApiKey = "AIzaSyBdiv-bTEMQDgVQxAWCaqs4s88IhuwTELA";

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
}
