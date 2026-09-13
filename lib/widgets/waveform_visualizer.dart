import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class WaveformVisualizer extends StatelessWidget {
  final double amplitude;
  final bool isRecording;
  final bool isPaused;

  const WaveformVisualizer({
    super.key,
    required this.amplitude,
    required this.isRecording,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    const barCount = 28;
    return RepaintBoundary(
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (index) {
            final factor = sin((index / barCount) * pi);
            final barHeight = isRecording
                ? (isPaused ? 8.0 : (16 + (amplitude * 50 * factor)).clamp(6.0, 65.0))
                : 8.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutQuad,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 3.5,
              height: barHeight,
              decoration: BoxDecoration(
                gradient: isRecording
                    ? (isPaused
                        ? const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF475569)])
                        : AppTheme.primaryGradient)
                    : const LinearGradient(colors: [Color(0xFF334155), Color(0xFF1E293B)]),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }
}
