import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../services/tts_service.dart';
import 'home_scanner_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();

    // Inisialisasi animasi logo & teks
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // Suara sambutan TTS
    await _ttsService.init();
    await _ttsService.speak("Selamat datang di MataSuara. Asisten Suara dan Scanner AI Anda.");

    // Beri jeda splash screen sebelum pindah ke layar utama
    await Future.delayed(const Duration(milliseconds: 2800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScannerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E40AF), // Deep Royal Blue
              Color(0xFF1D4ED8), // Primary Blue
              Color(0xFF0F172A), // Dark Slate
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo & Judul dengan Animasi Scale & Fade
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wadah Logo dengan Efek Glowing Shadow
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 130,
                                height: 130,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Judul Aplikasi
                          Text(
                            AppConfig.appName,
                            style: GoogleFonts.outfit(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline Aplikasi
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              AppConfig.appTagline,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Indikator Loading di Bagian Bawah
              const SpinKitThreeBounce(
                color: Colors.white70,
                size: 22,
              ),

              const SizedBox(height: 16),

              Text(
                "Memuat Asisten Suara & Kamera...",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
