import 'package:flutter/material.dart';
import '../services/game_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/answer_button.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final GameEngine engine;
  const GameScreen({super.key, required this.engine});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  bool _answered = false;
  late AnimationController _questionAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  String _currentQuestion = '';
  bool _historyExpanded = false;
  bool _topExpanded = true;

  @override
  void initState() {
    super.initState();
    _questionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _questionAnim, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _questionAnim, curve: Curves.easeOut);
    _refreshQuestion();
  }

  void _refreshQuestion() {
    setState(() {
      // Reads pre-selected attribute — never recomputes mid-question
      _currentQuestion = widget.engine.currentQuestion;
      _answered = false;
    });
    _questionAnim.forward(from: 0);
  }

  @override
  void dispose() {
    _questionAnim.dispose();
    super.dispose();
  }

  void _onAnswer(AnswerType ans) async {
    if (_answered) return;
    setState(() => _answered = true);

    widget.engine.answer(ans); // scores updated, candidate pool trimmed, next attr pre-selected

    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    if (widget.engine.shouldGuess || widget.engine.isMaxReached) {
      _goToResult();
    } else {
      _refreshQuestion();
    }
  }

  void _goToResult() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) => ResultScreen(engine: widget.engine),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  double get _progress =>
      widget.engine.questionCount / GameEngine.maxQuestions;

  @override
  Widget build(BuildContext context) {
    final q = widget.engine.questionCount;
    final remaining = widget.engine.candidateCount;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A3C), Color(0xFF0F0C1E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(q, remaining),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildAkinatorFace(),
                      const SizedBox(height: 20),
                      _buildQuestionBubble(),
                      const SizedBox(height: 24),
                      _buildAnswerButtons(),
                      const SizedBox(height: 16),
                      _buildGuessButton(),
                      const SizedBox(height: 16),
                      _buildTopCandidates(),
                      const SizedBox(height: 8),
                      if (widget.engine.history.isNotEmpty)
                        _buildHistorySection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int q, int remaining) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _confirmQuit,
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Soru $q / ${GameEngine.maxQuestions}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$remaining aday',
                        style: TextStyle(
                          color: AppTheme.accent.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                          AppTheme.accent, AppTheme.accentGold, _progress)!,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAkinatorFace() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            const RadialGradient(colors: [Color(0xFFB07FFF), Color(0xFF6C3FC5)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child:
          const Icon(Icons.psychology_rounded, size: 44, color: Colors.white),
    );
  }

  Widget _buildQuestionBubble() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _currentQuestion,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Column(
      children: AnswerType.values.map((type) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: AnswerButton(
            type: type,
            enabled: !_answered,
            onTap: () => _onAnswer(type),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGuessButton() {
    final pct =
        (widget.engine.confidence * 100).clamp(0, 100).toStringAsFixed(1);
    return OutlinedButton.icon(
      onPressed: widget.engine.questionCount >= 3 ? _goToResult : null,
      icon: const Icon(Icons.lightbulb_rounded, size: 18),
      label: Text('Tahminimi söyle! ($pct%)'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accentGold,
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.5)),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        disabledForegroundColor: Colors.white24,
      ),
    );
  }

  // ─── Live top-5 candidates panel ──────────────────────────────────────────

  Widget _buildTopCandidates() {
    final top = widget.engine.rankedCandidates.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _topExpanded = !_topExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'En olası tahminlerim',
                style: TextStyle(
                  color: AppTheme.accentGold.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _topExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.accentGold.withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
        if (_topExpanded) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (_, i) {
                final entry = top[i];
                final char = entry.key;
                final prob = entry.value;
                final pct = (prob * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0
                              ? AppTheme.accentGold.withOpacity(0.2)
                              : Colors.white.withOpacity(0.08),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == 0
                                  ? AppTheme.accentGold
                                  : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          char.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == 0 ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                      // Probability bar
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: i == 0
                                    ? AppTheme.accentGold
                                    : Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: prob.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  i == 0
                                      ? AppTheme.accentGold
                                      : AppTheme.accent.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    final history = widget.engine.history;
    return Column(
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _historyExpanded = !_historyExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sorular (${history.length})',
                style:
                    TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
              ),
              Icon(
                _historyExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white30,
                size: 18,
              ),
            ],
          ),
        ),
        if (_historyExpanded) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (_, i) {
                final item = history[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.questionText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _answerBadge(item.answer),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _answerBadge(AnswerType ans) {
    Color c;
    switch (ans) {
      case AnswerType.yes:         c = AppTheme.colorYes; break;
      case AnswerType.probably:    c = AppTheme.colorProbably; break;
      case AnswerType.dontKnow:    c = AppTheme.colorDontKnow; break;
      case AnswerType.probablyNot: c = AppTheme.colorProbablyNot; break;
      case AnswerType.no:          c = AppTheme.colorNo; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withOpacity(0.4), width: 1),
      ),
      child: Text(
        ans.label,
        style: TextStyle(
            fontSize: 10, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oyunu Bırak?'),
        content: const Text('İlerlemeniz kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam Et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.colorNo),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }
}
