import 'package:flutter/material.dart';
import '../services/universal_engine.dart';
import '../models/any_result.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'game_screen.dart';

enum _GuessStage { askingCorrect, correct, askingContinue, exhausted }

class ResultScreen extends StatefulWidget {
  final UniversalEngine engine;
  const ResultScreen({super.key, required this.engine});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  _GuessStage _stage = _GuessStage.askingCorrect;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _revealCtrl.forward();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  void _onCorrect() {
    setState(() => _stage = _GuessStage.correct);
  }

  void _onWrong() {
    setState(() => _stage = _GuessStage.askingContinue);
  }

  void _onContinue() {
    final hasMore = widget.engine.eliminateAndContinue();
    if (!hasMore) {
      setState(() => _stage = _GuessStage.exhausted);
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => GameScreen(engine: widget.engine),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
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

  void _showAlternativesSheet() {
    final top5 = widget.engine.top5Results;
    if (top5.length <= 1) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Diğer Tahminler',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...top5.skip(1).map((r) => _altCard(r)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guess = widget.engine.bestResult;

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
              _buildHeader(),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: _buildGuessCard(guess),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: _buildBottomArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final top5 = widget.engine.top5Results;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
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
          if (top5.length > 1)
            IconButton(
              onPressed: _showAlternativesSheet,
              icon: Icon(
                Icons.format_list_numbered_rounded,
                color: Colors.white.withOpacity(0.18),
                size: 22,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGuessCard(AnyResult guess) {
    final color = _categoryColor(guess.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.25), AppTheme.bgCard],
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                guess.name.isNotEmpty ? guess.name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            guess.isPerson ? 'Düşündüğünüz kişi...' : 'Düşündüğünüz şey...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 6),
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
          if (guess.category.isNotEmpty)
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
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (guess.description.isNotEmpty)
            Text(
              guess.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    switch (_stage) {
      case _GuessStage.askingCorrect:
        return _buildYesNoPrompt(
          prompt: 'Tahminim doğru mu?',
          onYes: _onCorrect,
          onNo:  _onWrong,
        );
      case _GuessStage.askingContinue:
        return _buildYesNoPrompt(
          prompt: 'Devam edelim mi?',
          onYes: _onContinue,
          onNo:  _playAgain,
        );
      case _GuessStage.correct:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bildim! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildNewGuessButton(),
          ],
        );
      case _GuessStage.exhausted:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Pes ediyorum, bilemedim 😅',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildNewGuessButton(),
          ],
        );
    }
  }

  Widget _buildYesNoPrompt({
    required String prompt,
    required VoidCallback onYes,
    required VoidCallback onNo,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            prompt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: onYes,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 24),
                  label: const Text(
                    'EVET',
                    style: TextStyle(fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: onNo,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 24),
                  label: const Text(
                    'HAYIR',
                    style: TextStyle(fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewGuessButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: _playAgain,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text(
          'YENİ TAHMİN',
          style: TextStyle(fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _altCard(AnyResult r) {
    final color = _categoryColor(r.category);
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
              r.name.isNotEmpty ? r.name.substring(0, 1) : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(r.category,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    // Person categories
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
    // Thing categories
    if (cat.contains('Hayvan')) return const Color(0xFF84CC16);
    if (cat.contains('Yiyecek') || cat.contains('İçecek') || cat.contains('Bitki')) return const Color(0xFFFF8C42);
    if (cat.contains('Taşıt') || cat.contains('Araç')) return const Color(0xFF38BDF8);
    if (cat.contains('Yer') || cat.contains('Mekan') || cat.contains('Coğrafya')) return const Color(0xFF34D399);
    if (cat.contains('Dijital') || cat.contains('Uygulama') || cat.contains('Oyun')) return const Color(0xFFA78BFA);
    if (cat.contains('Marka')) return const Color(0xFFFBBF24);
    if (cat.contains('Soyut') || cat.contains('Kavram') || cat.contains('Duygu')) return const Color(0xFFF472B6);
    if (cat.contains('Ev') || cat.contains('Mobilya') || cat.contains('Mutfak')) return const Color(0xFF94A3B8);
    if (cat.contains('Giyim') || cat.contains('Aksesuar')) return const Color(0xFFE879F9);
    if (cat.contains('Doğa')) return const Color(0xFF4ADE80);
    if (cat.contains('Uzay')) return const Color(0xFF818CF8);
    return AppTheme.accent;
  }
}
