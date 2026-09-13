import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Color? color;

  const StatusBadge({super.key, required this.status, this.color});

  @override
  Widget build(BuildContext context) {
    Color finalColor = color ?? AppTheme.primary;
    String label = status;
    IconData icon = Icons.info_outline;

    if (color == null) {
      switch (status.toLowerCase()) {
        case 'completed':
        case 'готов':
          finalColor = AppTheme.success;
          label = 'Готов (AI)';
          icon = Icons.auto_awesome;
          break;
        case 'transcribed':
        case 'транскрибировано':
          finalColor = AppTheme.secondary;
          label = 'Транскрибировано';
          icon = Icons.text_snippet;
          break;
        case 'transcribing':
        case 'транскрибация...':
          finalColor = AppTheme.warning;
          label = 'Транскрибация...';
          icon = Icons.sync;
          break;
        case 'summarizing':
        case 'ai анализ...':
          finalColor = AppTheme.accent;
          label = 'AI Анализ...';
          icon = Icons.psychology;
          break;
        case 'recorded':
        case 'записано':
          finalColor = AppTheme.primaryLight;
          label = 'Записано';
          icon = Icons.mic;
          break;
        case 'error':
        case 'ошибка':
          finalColor = AppTheme.error;
          label = 'Ошибка';
          icon = Icons.error_outline;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: finalColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: finalColor.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: finalColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: finalColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
