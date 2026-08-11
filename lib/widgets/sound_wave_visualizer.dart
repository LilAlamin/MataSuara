import 'package:flutter/material.dart';
import '../config/app_config.dart';

class SoundWaveVisualizer extends StatefulWidget {
  final bool isSpeaking;
  final String label;

  const SoundWaveVisualizer({
    super.key,
    required this.isSpeaking,
    this.label = "Menyuarakan Hasil AI...",
  });

  @override
  State<SoundWaveVisualizer> createState() => _SoundWaveVisualizerState();
}

class _SoundWaveVisualizerState extends State<SoundWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(5, (index) {
                  double factor = (index % 2 == 0)
                      ? _controller.value
                      : (1.0 - _controller.value);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 4,
                    height: 12 + (factor * 20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
