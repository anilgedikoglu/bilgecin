import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/game_engine.dart';
import '../models/character.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final GameEngine engine;
  const ResultScreen({super.key, required this.engine});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  bool? _wasCorrect;
  int _score = 0;
  final _textController = TextEditingController();
  bool _showAlternatives = false;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _revealCtrl.forward();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _textController.dispose();
    super.dispose();
  }

  int _calcScore(int questionCount) {
    if (questionCount <= 5) return 100;
    if (questionCount <= 10) return 80;
    if (questionCount <= 15) return 60;
    if (questionCount <= 20) return 40;
    return 20;
  }

  Future<void> _onCorrect() async {
    final score = _calcScore(widget.engine.questionCount);
    setState(() {
      _wasCorrect = true;
      _score = score;
    });
    await _saveScore(score);
  }

  Future<void> _onWrong() async {
    setState(() {
      _wasCorrect = false;
      _score = 0;
    });
    await _saveScore(0);
  }

  Future<void> _saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final high = prefs.getInt('high_score') ?? 0;
    if (score > high) await prefs.setInt('high_score', score);
    final played = (prefs.getInt('games_played') ?? 0) + 1;
    await prefs.setInt('games_played', played);
  }

  void _playAgain() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final guess = widget.engine.bestGuess;
    final q = widget.engine.questionCount;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: _buildGuessCard(guess, q),
                  ),
                ),
                const SizedBox(height: 28),
                if (_wasCorrect == null) ...[
                  _buildConfirmQuestion(guess),
                ] else ...[
                  _buildResultBanner(),
                  const SizedBox(height: 20),
                  if (_wasCorrect == false) _buildWrongSection(),
                  const SizedBox(height: 24),
                  _buildPlayAgainButton(),
                ],
                const SizedBox(height: 16),
                _buildAlternativesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _playAgain,
          icon: const Icon(Icons.home_rounded, color: Colors.white54),
        ),
        const Expanded(
          child: Text(
            'TAHMİNİM',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildGuessCard(Character guess, int questionCount) {
    final color = _categoryColor(guess.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.25),
            AppTheme.bgCard,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.8), color.withOpacity(0.3)],
              ),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                guess.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Intro text
          Text(
            'Düşündüğünüz kişi...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            guess.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.6)),
            ),
            child: Text(
              guess.category,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          // Nationality
          Text(
            '${guess.nationality} • ${guess.knownFor}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniStat('⚡', '$questionCount soru'),
              const SizedBox(width: 16),
              _miniStat('⭐', '${guess.popularityScore}/100'),
              const SizedBox(width: 16),
              _miniStat('📅', '${guess.birthYear}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$emoji $text',
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }

  Widget _buildConfirmQuestion(Character guess) {
    return Column(
      children: [
        Text(
          'Bu doğru mu?',
          style: TextStyle(
            fontSize: 17,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _bigButton(
                label: '✅  Evet, doğru!',
                color: AppTheme.colorYes,
                onTap: _onCorrect,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigButton(
                label: '❌  Hayır, yanlış',
                color: AppTheme.colorNo,
                onTap: _onWrong,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigButton(
      {required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    if (_wasCorrect == true) {
      final score = _score;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.colorYes.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.colorYes.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            const Text(
              'Buldum!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Puan: $score',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppTheme.accentGold,
              ),
            ),
            Text(
              '${widget.engine.questionCount} soruda bulundu',
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildWrongSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Kimin düşündüğünüzü yazın...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppTheme.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppTheme.accent.withOpacity(0.6)),
            ),
            prefixIcon:
                const Icon(Icons.person_rounded, color: Colors.white38),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // In a real app, this would send feedback to improve the model
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Geri bildirim için teşekkürler! "${_textController.text}"',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.bgCard,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Gönder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(color: AppTheme.accent.withOpacity(0.5)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayAgainButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: _playAgain,
        icon: const Icon(Icons.refresh_rounded, size: 24),
        label: const Text(
          'TEKRAR OYNA',
          style: TextStyle(fontSize: 17, letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildAlternativesSection() {
    final top5 = widget.engine.top5;
    if (top5.length <= 1) return const SizedBox.shrink();

    return Column(
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _showAlternatives = !_showAlternatives),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Diğer Tahminler',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
              Icon(
                _showAlternatives
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
        if (_showAlternatives) ...[
          const SizedBox(height: 8),
          ...top5.skip(1).map((c) => _altCard(c)),
        ],
      ],
    );
  }

  Widget _altCard(Character c) {
    final color = _categoryColor(c.category);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.25),
            child: Text(
              c.name.substring(0, 1),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(c.category,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ),
          Text(c.nationality,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.35))),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    if (cat.contains('Futbolcu')) return const Color(0xFF22C55E);
    if (cat.contains('Müzisyen') || cat.contains('Şarkıcı')) return const Color(0xFFEC4899);
    if (cat.contains('Rapper')) return const Color(0xFF8B5CF6);
    if (cat.contains('Oyuncu')) return const Color(0xFFF59E0B);
    if (cat.contains('Siyaset')) return const Color(0xFF3B82F6);
    if (cat.contains('Anime')) return const Color(0xFFEF4444);
    if (cat.contains('Dizi') || cat.contains('TV')) return const Color(0xFF06B6D4);
    if (cat.contains('Film') || cat.contains('Kurgusal')) return const Color(0xFFFF7A00);
    if (cat.contains('Sporcu') || cat.contains('Basket') || cat.contains('Tenis')) {
      return const Color(0xFF10B981);
    }
    if (cat.contains('Tarihi') || cat.contains('Osmanlı')) return const Color(0xFFD97706);
    if (cat.contains('YouTuber')) return const Color(0xFFFF0000);
    if (cat.contains('Bilim') || cat.contains('Yazar')) return const Color(0xFF60A5FA);
    return AppTheme.accent;
  }
}
