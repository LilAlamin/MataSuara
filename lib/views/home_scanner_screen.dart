import 'package:camera/camera.dart';
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

  ScanMode _selectedMode = ScanMode.objectScene;
  bool _isAnalyzing = false;
  bool _isListening = false;
  String _lastResultText = "Tekan 'PINDAI SEKARANG' untuk memindai benda di depan Anda.";

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

    // Salam selamat datang otomatis dalam suara
    _ttsService.speak(
        "Aplikasi siap digunakan. Silakan pilih mode dan tekan tombol Pindai.");
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
            _selectedMode = ScanMode.voiceQuery;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 Background
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 2,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.secondaryEmerald],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 42,
                  height: 42,
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
                      letterSpacing: 0.5,
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
            // Mode Selector Grid
            _buildModeSelector(),

            // Camera Viewfinder Display dengan Reticle Corner Overlay
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primaryBlue, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Stream
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
                                Icon(Icons.camera_alt_rounded, size: 54, color: Colors.white54),
                                SizedBox(height: 12),
                                Text(
                                  "Menyiapkan Kamera...",
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Scanner Frame Reticle Corner Overlays (WCAG Visual Focus)
                      _buildCameraReticle(),

                      // Mode Badge Tag (Atas Kiri Kamera)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getIconForMode(_selectedMode), color: Colors.white, size: 16),
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

                      // Sound Wave Visualizer ketika AI bicara / dengerin
                      Positioned(
                        top: 14,
                        right: 14,
                        child: SoundWaveVisualizer(
                          isSpeaking: _ttsService.isSpeaking || _isListening,
                          label: _isListening ? "Mendengarkan..." : "Bicara AI...",
                        ),
                      ),

                      // Overlay Loading Scanner
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
                                const SizedBox(height: 20),
                                Text(
                                  "Sedang Memproses AI Vision...",
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

            // Card Output Teks Hasil AI (High Contrast WCAG AAA)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3), width: 2),
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
                          Icon(_getIconForMode(_selectedMode), color: AppColors.primaryBlue, size: 20),
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
                  Text(
                    _lastResultText,
                    style: GoogleFonts.inter(
                      color: AppColors.textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tombol Aksi Raksasa (Large Tap Target untuk Aksesibilitas Netra)
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

  Widget _buildCameraReticle() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Top-left corner
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.primaryBlue, width: 4),
                    left: BorderSide(color: AppColors.primaryBlue, width: 4),
                  ),
                ),
              ),
            ),
            // Top-right corner
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.primaryBlue, width: 4),
                    right: BorderSide(color: AppColors.primaryBlue, width: 4),
                  ),
                ),
              ),
            ),
            // Bottom-left corner
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.primaryBlue, width: 4),
                    left: BorderSide(color: AppColors.primaryBlue, width: 4),
                  ),
                ),
              ),
            ),
            // Bottom-right corner
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.primaryBlue, width: 4),
                    right: BorderSide(color: AppColors.primaryBlue, width: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          _buildModeTab(ScanMode.objectScene, "Benda", Icons.view_in_ar_rounded, AppColors.modeObject),
          _buildModeTab(ScanMode.textReader, "Teks", Icons.text_snippet_rounded, AppColors.modeText),
          _buildModeTab(ScanMode.currency, "Uang", Icons.attach_money_rounded, AppColors.modeCurrency),
          _buildModeTab(ScanMode.voiceQuery, "Tanya", Icons.mic_rounded, AppColors.modeVoice),
        ],
      ),
    );
  }

  Widget _buildModeTab(ScanMode mode, String label, IconData icon, Color activeColor) {
    bool isSelected = _selectedMode == mode;
    return Expanded(
      child: Semantics(
        selected: isSelected,
        label: "Mode ${_getTitleForMode(mode)}",
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
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.textSubtle,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
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

  String _getTitleForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.objectScene:
        return "Deteksi Benda & Ruangan";
      case ScanMode.textReader:
        return "Pembaca Teks & Dokumen";
      case ScanMode.currency:
        return "Deteksi Uang Rupiah";
      case ScanMode.voiceQuery:
        return "Tanya Jawab Suara";
    }
  }

  IconData _getIconForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.objectScene:
        return Icons.view_in_ar_rounded;
      case ScanMode.textReader:
        return Icons.text_snippet_rounded;
      case ScanMode.currency:
        return Icons.attach_money_rounded;
      case ScanMode.voiceQuery:
        return Icons.mic_rounded;
    }
  }
}
