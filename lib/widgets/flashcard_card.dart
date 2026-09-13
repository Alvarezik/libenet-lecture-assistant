import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'glass_container.dart';

class FlashcardCard extends StatefulWidget {
  final String question;
  final String answer;
  final int index;
  final int? total;

  const FlashcardCard({
    super.key,
    required this.question,
    required this.answer,
    required this.index,
    this.total,
  });

  @override
  State<FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<FlashcardCard> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 18,
      backgroundColor: _showAnswer ? const Color(0x2E10B981) : const Color(0x1E334155),
      border: Border.all(
        color: _showAnswer ? AppTheme.success.withOpacity(0.4) : const Color(0x33475569),
        width: 1.2,
      ),
      onTap: () {
        setState(() {
          _showAnswer = !_showAnswer;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.total != null ? 'Карточка ${widget.index} из ${widget.total}' : 'Карточка #${widget.index}',
                  style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                children: [
                  Text(
                    _showAnswer ? 'Скрыть ответ' : 'Нажмите, чтобы узнать ответ',
                    style: TextStyle(
                      color: _showAnswer ? AppTheme.success : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showAnswer ? Icons.visibility_off_outlined : Icons.touch_app_outlined,
                    size: 14,
                    color: _showAnswer ? AppTheme.success : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline_rounded, color: AppTheme.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_showAnswer) ...[
            const Divider(color: Color(0x2210B981), height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.answer,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6EE7B7),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
