import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/accessible_button.dart';
import '../widgets/sound_wave_visualizer.dart';

class HomeScannerScreen extends StatefulWidget {
  const HomeScannerScreen({super.key});

  @override
  State<HomeScannerScreen> createState() => _HomeScannerScreenState();
}

class _HomeScannerScreenState extends State<HomeScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  final GeminiService _geminiService = GeminiService();
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();

  ScanMode _selectedMode = ScanMode.scan;
  bool _isAnalyzing = false;
  bool _isListening = false;
  String _lastResultText = "Tekan 'PINDAI SEKARANG' untuk memindai benda atau petunjuk arah di depan Anda.";

  int _highlightStart = -1;
  int _highlightEnd = -1;

  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _initAppServices();
  }

  Future<void> _initAppServices() async {
    await _requestPermissions();
    await _initCamera();
    await _ttsService.init();
    await _speechService.init();

    _ttsService.onProgress = (start, end) {
      if (mounted) {
        setState(() {
          _highlightStart = start;
          _highlightEnd = end;
        });
      }
    };

    // Salam selamat datang otomatis dalam suara
    _ttsService.speak(
        "Aplikasi siap digunakan. Silakan pilih mode Scan atau Petunjuk Arah dan tekan tombol Pindai.");
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0], // Gunakan kamera belakang
          ResolutionPreset.medium, // Menggunakan medium agar smooth & tidak lag di emulator
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal menginisialisasi kamera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ttsService.dispose();
    _speechService.stop();
    super.dispose();
  }

  Future<void> _captureAndAnalyze({String? customQuestion}) async {
    if (_isAnalyzing) return;

    HapticFeedback.heavyImpact();
    await _ttsService.stop();

    setState(() {
      _isAnalyzing = true;
      _lastResultText = "Sedang memproses gambar dengan AI...";
    });

    try {
      Uint8List imageBytes;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        XFile file = await _cameraController!.takePicture();
        imageBytes = await file.readAsBytes();
      } else {
        // Fallback dummy image jika berjalan di simulator tanpa kamera fisik
        imageBytes = Uint8List(0);
      }

      String aiResponse = await _geminiService.analyzeImage(
        imageBytes: imageBytes,
        mode: _selectedMode,
        userQuestion: customQuestion,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _lastResultText = aiResponse;
        });

        // Menyuarakan respon AI secara otomatis & getar haptic konfirmasi
        HapticFeedback.vibrate();
        await _ttsService.speak(aiResponse);
      }
    } catch (e) {
      debugPrint("Error capture and analyze: $e");
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _lastResultText = "Terjadi kendala: $e";
        });
        _ttsService.speak("Terjadi kesalahan saat memproses gambar.");
      }
    }
  }

  void _startVoiceQueryMode() async {
    await _ttsService.stop();
    // Tunggu hingga petunjuk suara selesai diucapkan sepenuhnya
    await _ttsService.speakAndWait("Silakan ucapkan pertanyaan Anda.");

    // Jeda 300ms agar mikrofon tidak menangkap sisa gema suara speaker
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isListening = true;
    });

    await _speechService.listen(
      onResult: (text) {
        if (text.isNotEmpty) {
          setState(() {
            _selectedMode = ScanMode.scan;
            _isListening = false;
          });
          _captureAndAnalyze(customQuestion: text);
        }
      },
      onListeningComplete: () {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return isIOS ? _buildIosLayout() : _buildAndroidLayout();
  }

  // ==========================================
  // ANDROID MATERIAL 3 LIGHTWEIGHT LAYOUT
  // ==========================================
  Widget _buildAndroidLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        toolbarHeight: 68,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.secondaryEmerald],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppConfig.appName,
                    style: GoogleFonts.outfit(
                      color: AppColors.primaryBlue,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    AppConfig.appTagline,
                    style: GoogleFonts.inter(
                      color: AppColors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Semantics(
            label: "Ulangi Suara Terakhir",
            button: true,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue, size: 22),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _ttsService.speak(_lastResultText);
              },
              tooltip: "Ulangi Suara Terakhir",
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Lightweight Material 2-Mode Selector
            _buildAndroidModeSelector(),

            // Camera Viewfinder (Ringan & Cepat tanpa Blur GPU)
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primaryBlue, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isCameraInitialized && _cameraController != null)
                        SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cameraController!.value.previewSize?.height ?? 100,
                              height: _cameraController!.value.previewSize?.width ?? 100,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFF0F172A),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 52, color: Colors.white54),
                                SizedBox(height: 12),
                                Text(
                                  "Menyiapkan Kamera...",
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),

                      _buildCameraReticle(),

                      // Mode Badge Ringan
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getMaterialIconForMode(_selectedMode), color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _getTitleForMode(_selectedMode),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 14,
                        right: 14,
                        child: SoundWaveVisualizer(
                          isSpeaking: _ttsService.isSpeaking || _isListening,
                          label: _isListening ? "Mendengarkan..." : "Bicara AI...",
                        ),
                      ),

                      if (_isAnalyzing)
                        Container(
                          color: Colors.black.withValues(alpha: 0.75),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.secondaryEmerald,
                                  strokeWidth: 4,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  "Sedang Memproses AI...",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Card Output Teks Hasil AI Android
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getMaterialIconForMode(_selectedMode), color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "HASIL DETEKSI",
                            style: GoogleFonts.outfit(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _ttsService.speak(_lastResultText);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "Putar",
                                style: GoogleFonts.inter(
                                  color: AppColors.primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightedResultText(_lastResultText, isIosStyle: false),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tombol Aksi Material Android
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  AccessibleButton(
                    label: _isAnalyzing ? "MEMPROSES AI..." : "PINDAI SEKARANG",
                    icon: Icons.camera_enhance_rounded,
                    backgroundColor: AppColors.primaryBlue,
                    textColor: Colors.white,
                    isLoading: _isAnalyzing,
                    onPressed: () => _captureAndAnalyze(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AccessibleButton(
                          label: _isListening ? "Mendengarkan..." : "Tanya Suara",
                          icon: _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                          backgroundColor: AppColors.modeVoice,
                          textColor: Colors.white,
                          isPrimary: false,
                          onPressed: _startVoiceQueryMode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AccessibleButton(
                          label: "Stop Suara",
                          icon: Icons.stop_circle_rounded,
                          backgroundColor: const Color(0xFFDC2626),
                          textColor: Colors.white,
                          isPrimary: false,
                          onPressed: () => _ttsService.stop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          _buildAndroidModeTab(ScanMode.scan, "Scan", Icons.qr_code_scanner_rounded, AppColors.primaryBlue),
          _buildAndroidModeTab(ScanMode.navigation, "Petunjuk Arah", Icons.explore_rounded, AppColors.secondaryEmerald),
        ],
      ),
    );
  }

  Widget _buildAndroidModeTab(ScanMode mode, String label, IconData icon, Color activeColor) {
    bool isSelected = _selectedMode == mode;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        label: "Mode $label",
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMode = mode;
              });
              _ttsService.speak("Mode terpilih: ${_getTitleForMode(mode)}");
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppColors.textSubtle,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // iOS CUPERTINO HIG LAYOUT
  // ==========================================
  Widget _buildIosLayout() {
    return Scaffold(
      backgroundColor: AppColors.iosBackground, // iOS System Grouped Background #F2F2F7
      body: Stack(
        children: [
          // Content Area
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 64), // Spacing for translucent floating navigation bar

                // iOS Segmented Control Selector
                _buildIosSegmentedControl(),

                // iOS Native Camera Viewfinder (Rounded Glass Container)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(32), // iOS Smooth Continuous Corner
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.iosSystemBlue.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Camera Preview Stream
                          if (_isCameraInitialized && _cameraController != null)
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _cameraController!.value.previewSize?.height ?? 100,
                                  height: _cameraController!.value.previewSize?.width ?? 100,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            )
                          else
                            Container(
                              color: const Color(0xFF0D0D12),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.camera_fill, size: 54, color: Colors.white38),
                                    SizedBox(height: 12),
                                    Text(
                                      "Menyiapkan Kamera...",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // iOS Camera Frame Reticle Overlay
                          _buildIosCameraReticle(),

                          // Mode Badge Overlay (Pojok Kiri Atas Kamera - iOS Frosted Glass Chip)
                          Positioned(
                            top: 14,
                            left: 14,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getCupertinoIconForMode(_selectedMode), color: Colors.white, size: 15),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getTitleForMode(_selectedMode),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Sound Wave Visualizer
                          Positioned(
                            top: 14,
                            right: 14,
                            child: SoundWaveVisualizer(
                              isSpeaking: _ttsService.isSpeaking || _isListening,
                              label: _isListening ? "Mendengarkan..." : "Bicara AI...",
                            ),
                          ),

                          // Overlay Loading AI
                          if (_isAnalyzing)
                            Container(
                              color: Colors.black.withValues(alpha: 0.75),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CupertinoActivityIndicator(
                                      color: Colors.white,
                                      radius: 18,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      "Memproses dengan AI...",
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // iOS Inset Grouped Card (Hasil Deteksi AI - High Contrast WCAG AAA)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.iosSecondaryBackground,
                    borderRadius: BorderRadius.circular(22), // iOS Smooth continuous corners
                    border: Border.all(color: AppColors.iosSystemGray5, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_getCupertinoIconForMode(_selectedMode), color: AppColors.iosSystemBlue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "HASIL DETEKSI",
                                style: GoogleFonts.outfit(
                                  color: AppColors.iosSystemBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          Semantics(
                            label: "Putar Ulang Suara Hasil",
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  _ttsService.speak(_lastResultText);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.iosSystemBlue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.speaker_2_fill, color: AppColors.iosSystemBlue, size: 14),
                                      const SizedBox(width: 5),
                                      Text(
                                        "Putar",
                                        style: GoogleFonts.inter(
                                          color: AppColors.iosSystemBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildHighlightedResultText(_lastResultText, isIosStyle: true),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // iOS Action Dock Buttons (Camera Shutter & Voice Actions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Large iOS Camera Shutter Action Button
                      AccessibleButton(
                        label: _isAnalyzing ? "MEMPROSES AI..." : "PINDAI SEKARANG",
                        icon: CupertinoIcons.camera_fill,
                        backgroundColor: AppColors.iosSystemBlue,
                        textColor: Colors.white,
                        isLoading: _isAnalyzing,
                        onPressed: () => _captureAndAnalyze(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AccessibleButton(
                              label: _isListening ? "Mendengarkan..." : "Tanya Suara",
                              icon: _isListening ? CupertinoIcons.waveform : CupertinoIcons.mic_fill,
                              backgroundColor: AppColors.iosSystemIndigo,
                              textColor: Colors.white,
                              isPrimary: false,
                              onPressed: _startVoiceQueryMode,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AccessibleButton(
                              label: "Stop Suara",
                              icon: CupertinoIcons.stop_fill,
                              backgroundColor: AppColors.iosSystemRed,
                              textColor: Colors.white,
                              isPrimary: false,
                              onPressed: () => _ttsService.stop(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // Floating iOS Translucent Frosted Glass Navigation Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 6,
                    bottom: 10,
                    left: 18,
                    right: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    border: const Border(
                      bottom: BorderSide(color: Color(0x1F000000), width: 0.5), // Subtle iOS hairline border
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [AppColors.iosSystemBlue, AppColors.iosSystemGreen],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppConfig.appName,
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              AppConfig.appTagline,
                              style: GoogleFonts.inter(
                                color: AppColors.iosSystemGray,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: "Ulangi Suara Terakhir",
                        button: true,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 38,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.iosSystemBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.speaker_2_fill, color: AppColors.iosSystemBlue, size: 18),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _ttsService.speak(_lastResultText);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraReticle() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(22),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.primaryBlue, width: 3),
                    left: BorderSide(color: AppColors.primaryBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.primaryBlue, width: 3),
                    right: BorderSide(color: AppColors.primaryBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.primaryBlue, width: 3),
                    left: BorderSide(color: AppColors.primaryBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.primaryBlue, width: 3),
                    right: BorderSide(color: AppColors.primaryBlue, width: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosCameraReticle() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(22),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                    left: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                    right: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                    left: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                    right: BorderSide(color: AppColors.iosSystemBlue, width: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosSegmentedControl() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<ScanMode>(
        groupValue: _selectedMode,
        backgroundColor: const Color(0x1E767680), // Native iOS Segmented Control background
        thumbColor: Colors.white,
        padding: const EdgeInsets.all(3),
        children: {
          ScanMode.scan: _buildIosSegmentTab(
            ScanMode.scan,
            "Scan",
            CupertinoIcons.viewfinder,
          ),
          ScanMode.navigation: _buildIosSegmentTab(
            ScanMode.navigation,
            "Petunjuk Arah",
            CupertinoIcons.compass_fill,
          ),
        },
        onValueChanged: (ScanMode? value) {
          if (value != null) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedMode = value;
            });
            _ttsService.speak("Mode terpilih: ${_getTitleForMode(value)}");
          }
        },
      ),
    );
  }

  Widget _buildIosSegmentTab(ScanMode mode, String label, IconData icon) {
    bool isSelected = _selectedMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.iosSystemBlue : AppColors.iosSystemGray,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.black : const Color(0xFF3C3C43),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitleForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.scan:
        return "Scan All-in-One (Benda, Teks, Uang)";
      case ScanMode.navigation:
        return "Petunjuk Arah & Navigasi Ruangan";
    }
  }

  IconData _getCupertinoIconForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.scan:
        return CupertinoIcons.viewfinder;
      case ScanMode.navigation:
        return CupertinoIcons.compass_fill;
    }
  }

  IconData _getMaterialIconForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.scan:
        return Icons.qr_code_scanner_rounded;
      case ScanMode.navigation:
        return Icons.explore_rounded;
    }
  }

  Widget _buildHighlightedResultText(String text, {required bool isIosStyle}) {
    final primaryColor = isIosStyle ? AppColors.iosSystemBlue : AppColors.primaryBlue;

    Widget textWidget;

    if (_highlightStart >= 0 &&
        _highlightEnd > _highlightStart &&
        _highlightEnd <= text.length) {
      final before = text.substring(0, _highlightStart);
      final highlighted = text.substring(_highlightStart, _highlightEnd);
      final after = text.substring(_highlightEnd);

      textWidget = RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            color: AppColors.textDark,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: isIosStyle ? -0.3 : 0.0,
          ),
          children: [
            TextSpan(text: before),
            TextSpan(
              text: highlighted,
              style: GoogleFonts.inter(
                color: primaryColor,
                backgroundColor: primaryColor.withValues(alpha: 0.2),
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: after),
          ],
        ),
      );
    } else {
      textWidget = Text(
        text,
        style: GoogleFonts.inter(
          color: AppColors.textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.45,
          letterSpacing: isIosStyle ? -0.3 : 0.0,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 160),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: textWidget,
      ),
    );
  }
}
