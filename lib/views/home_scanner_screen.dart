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
        "Selamat datang di VisionAssist AI. Aplikasi siap digunakan. Silakan pilih mode dan tekan tombol Pindai.");
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConfig.appName,
              style: GoogleFonts.outfit(
                color: AppColors.primaryBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppConfig.appTagline,
              style: GoogleFonts.inter(
                color: AppColors.textSubtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primaryBlue),
            onPressed: () => _showApiKeyDialog(context),
            tooltip: "Pengaturan API Key",
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _ttsService.speak(_lastResultText);
            },
            tooltip: "Ulangi Suara Terakhir",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Selector Bar
            _buildModeSelector(),

            // Camera Preview Display dengan Card Light Glassmorphism
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Stream
                      if (_isCameraInitialized && _cameraController != null)
                        CameraPreview(_cameraController!)
                      else
                        Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.textSubtle),
                                SizedBox(height: 12),
                                Text(
                                  "Menyiapkan Kamera...",
                                  style: TextStyle(color: AppColors.textSubtle, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Sound Wave Visualizer ketika AI bicara
                      Positioned(
                        top: 16,
                        child: SoundWaveVisualizer(
                          isSpeaking: _ttsService.isSpeaking || _isListening,
                          label: _isListening ? "Mendengarkan Suara..." : "Menyuarakan Hasil AI...",
                        ),
                      ),

                      // Overlay Loading Scanner
                      if (_isAnalyzing)
                        Container(
                          color: Colors.white.withValues(alpha: 0.85),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.primaryBlue,
                                  strokeWidth: 4,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "Sedang Memproses AI Vision...",
                                  style: GoogleFonts.outfit(
                                    color: AppColors.textDark,
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

            // Card Output Teks Hasil AI (Light Mode High-Contrast)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(18),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getIconForMode(_selectedMode), color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _getTitleForMode(_selectedMode).toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastResultText,
                    style: GoogleFonts.inter(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tombol Aksi Raksasa (Large Tap Target untuk Aksesibilitas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  AccessibleButton(
                    label: _isAnalyzing ? "MEMPROSES..." : "PINDAI SEKARANG",
                    icon: Icons.center_focus_strong_rounded,
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
                          label: "Tanya Suara",
                          icon: Icons.mic_rounded,
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
                          backgroundColor: const Color(0xFFEF4444),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildModeChip(ScanMode.objectScene, "📦 Benda & Ruangan", AppColors.modeObject),
          _buildModeChip(ScanMode.textReader, "📝 Teks & Dokumen", AppColors.modeText),
          _buildModeChip(ScanMode.currency, "💵 Uang Rupiah", AppColors.modeCurrency),
          _buildModeChip(ScanMode.voiceQuery, "🎙️ Tanya AI", AppColors.modeVoice),
        ],
      ),
    );
  }

  Widget _buildModeChip(ScanMode mode, String label, Color accentColor) {
    bool isSelected = _selectedMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedColor: accentColor,
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: isSelected ? accentColor : AppColors.borderLight,
          width: 1.5,
        ),
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onSelected: (selected) {
          if (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedMode = mode;
            });
            _ttsService.speak("Mode terpilih: ${_getTitleForMode(mode)}");
          }
        },
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

  void _showApiKeyDialog(BuildContext context) {
    final geminiController = TextEditingController(text: AppConfig.geminiApiKey);
    final gcpTtsController = TextEditingController(text: AppConfig.gcpTtsApiKey);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            "Pengaturan API Key",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: geminiController,
                decoration: const InputDecoration(
                  labelText: "Gemini AI API Key",
                  hintText: "Masukkan API Key Gemini",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gcpTtsController,
                decoration: const InputDecoration(
                  labelText: "GCP Cloud TTS API Key (GCP Credits)",
                  hintText: "Opsional (Jika pakai Cloud TTS)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              onPressed: () {
                setState(() {
                  AppConfig.geminiApiKey = geminiController.text.trim();
                  AppConfig.gcpTtsApiKey = gcpTtsController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("API Key berhasil disimpan.")),
                );
              },
              child: const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
