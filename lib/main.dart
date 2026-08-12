import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_config.dart';
import 'views/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VisionAssistApp());
}

class VisionAssistApp extends StatelessWidget {
  const VisionAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: Brightness.light,
          primary: AppColors.primaryBlue,
          secondary: AppColors.secondaryEmerald,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
