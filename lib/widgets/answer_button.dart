import 'package:flutter/material.dart';
import '../services/game_engine.dart';
import '../theme/app_theme.dart';

class AnswerButton extends StatefulWidget {
  final AnswerType type;
  final VoidCallback onTap;
  final bool enabled;

  const AnswerButton({
    super.key,
    required this.type,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.type) {
      case AnswerType.yes: return AppTheme.colorYes;
      case AnswerType.probably: return AppTheme.colorProbably;
      case AnswerType.dontKnow: return AppTheme.colorDontKnow;
      case AnswerType.probablyNot: return AppTheme.colorProbablyNot;
      case AnswerType.no: return AppTheme.colorNo;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case AnswerType.yes: return Icons.check_circle_rounded;
      case AnswerType.probably: return Icons.thumb_up_rounded;
      case AnswerType.dontKnow: return Icons.help_rounded;
      case AnswerType.probablyNot: return Icons.thumb_down_rounded;
      case AnswerType.no: return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
        onTapUp: widget.enabled
            ? (_) {
                _ctrl.reverse();
                widget.onTap();
              }
            : null,
        onTapCancel: widget.enabled ? () => _ctrl.reverse() : null,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _color.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon, color: _color, size: 22),
                const SizedBox(width: 10),
                Text(
                  widget.type.label,
                  style: TextStyle(
                    color: _color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
