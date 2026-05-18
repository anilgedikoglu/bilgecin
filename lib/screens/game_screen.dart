import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/game_engine.dart' show AnswerType, AnswerTypeExt;
import '../services/universal_engine.dart';
import 'result_screen.dart';

// Single accent color picked from tamua.png palette (deep violet)
const _kBtnColor = Color(0xFF7B35C0);

// Soru üstü görseller — her soruda random seçilir
const _kSoruGorselleri = [
  'assets/tamua.png',
  'assets/tamuaicons.png',
  'assets/soru_gorselleri/sg1.png',
  'assets/soru_gorselleri/sg2.png',
  'assets/soru_gorselleri/sg3.png',
  'assets/soru_gorselleri/sg4.png',
  'assets/soru_gorselleri/sg5.png',
  'assets/soru_gorselleri/sg6.png',
  'assets/soru_gorselleri/sg7.png',
  'assets/soru_gorselleri/sg8.png',
  'assets/soru_gorselleri/sg9.png',
  'assets/soru_gorselleri/sg10.png',
  'assets/soru_gorselleri/sg11.png',
  'assets/soru_gorselleri/sg12.png',
  'assets/soru_gorselleri/sg13.png',
  'assets/soru_gorselleri/sg14.png',
  'assets/soru_gorselleri/sg15.png',
  'assets/soru_gorselleri/sg16.png',
  'assets/soru_gorselleri/sg17.png',
  'assets/soru_gorselleri/sg18.png',
];

class GameScreen extends StatefulWidget {
  final UniversalEngine engine;
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
  String _topImage = _kSoruGorselleri[0];
  final _rng = Random();

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
    String next;
    do {
      next = _kSoruGorselleri[_rng.nextInt(_kSoruGorselleri.length)];
    } while (next == _topImage && _kSoruGorselleri.length > 1);
    debugPrint('GORSEL_SECILDI: $next  (liste boyutu: ${_kSoruGorselleri.length})');
    setState(() {
      _currentQuestion = widget.engine.currentQuestion;
      _answered = false;
      _topImage = next;
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

    widget.engine.answer(ans);

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

  void _showDebugPanel() {
    final top = widget.engine.rankedResults;
    final count = widget.engine.candidateCount;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1840),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Adaylar ($count)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: top.length,
            itemBuilder: (_, i) {
              final entry = top[i];
              final pct = (entry.value * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0
                            ? _kBtnColor.withOpacity(0.3)
                            : Colors.white.withOpacity(0.08),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == 0 ? _kBtnColor : Colors.white54,
                            )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: i == 0 ? Colors.white : Colors.white70,
                          fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        color: i == 0 ? _kBtnColor : Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: _kBtnColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topH = mq.size.height * 0.52;
    final statusBarH = mq.padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Üst yarı: tamua.png + gradient overlay ──────────────────────
          SizedBox(
            height: topH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _topImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.red.shade900,
                    child: Center(
                      child: Text(_topImage,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ),
                // Gradient: şeffaf üst → simsiyah alt
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Color(0x55000000),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
                // Üst kontroller
                Positioned(
                  top: statusBarH + 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home_rounded, color: Colors.white70),
                        onPressed: _confirmQuit,
                      ),
                      if (kDebugMode)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bug_report_rounded, color: Colors.white38),
                              onPressed: _showDebugPanel,
                            ),
                            Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                _topImage.split('/').last,
                                style: const TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Alt yarı: siyah zemin, soru + butonlar ──────────────────────
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Soru metni
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Text(
                        _currentQuestion,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Cevap butonları: 2 üstte, 3 altta
                  _buildAnswerButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _answerBtn(AnswerType.probably)),
            const SizedBox(width: 8),
            Expanded(child: _answerBtn(AnswerType.probablyNot)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _answerBtn(AnswerType.yes)),
            const SizedBox(width: 8),
            Expanded(child: _answerBtn(AnswerType.dontKnow)),
            const SizedBox(width: 8),
            Expanded(child: _answerBtn(AnswerType.no)),
          ],
        ),
      ],
    );
  }

  Widget _answerBtn(AnswerType type) {
    final enabled = !_answered;
    return GestureDetector(
      onTap: enabled ? () => _onAnswer(type) : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _kBtnColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBtnColor.withOpacity(0.55), width: 1.2),
          ),
          child: Center(
            child: Text(
              type.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1840),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oyunu Bırak?', style: TextStyle(color: Colors.white)),
        content: const Text('İlerlemeniz kaybolacak.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam Et', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kBtnColor),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }
}
