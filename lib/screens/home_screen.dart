import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../services/data_service.dart';
import '../services/things_data_service.dart';
import '../services/universal_engine.dart';
import '../services/game_engine.dart' show AnswerType, AnswerTypeExt;
import '../models/any_result.dart';

const _kBg         = Color(0xFF0F0C1E);
const _kBtnColor   = Color(0xFF7B35C0);
const _kTextLight  = Colors.white;
const _kSubtleText = Color(0xFF9B8EC4);
const _kCardBg     = Color(0xFF1A1035);

enum _Phase { idle, game, result }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {

  _Phase _phase   = _Phase.idle;
  bool   _loading = false;
  UniversalEngine? _engine;
  bool   _answered        = false;
  String _currentQuestion = '';
  int    _questionCount   = 0; // çift→frame33, tek→frame39

  late final AnimationController _exitCtrl;
  late final AnimationController _questionCtrl;
  late final Animation<double>   _questionFade;
  late final Animation<Offset>   _questionSlide;
  late final AnimationController _resultCtrl;
  late final Animation<double>   _resultFade;
  late final Animation<double>   _resultScale;

  // BİLGECİN — her harf farklı yönde uçar
  static const _letters = ['B', 'İ', 'L', 'G', 'E', 'C', 'İ', 'N'];
  static const _ldx     = [-40.0, -12.0, -75.0,  22.0,  65.0, -28.0,  45.0,  18.0];
  static const _ldy     = [-220.0, -300.0, -260.0, -290.0, -235.0, -320.0, -275.0, -210.0];

  @override
  void initState() {
    super.initState();

    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _questionCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _questionFade = CurvedAnimation(parent: _questionCtrl, curve: Curves.easeOut);
    _questionSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _questionCtrl, curve: Curves.easeOut));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _resultFade  = CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut);
    _resultScale = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
    _questionCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _startGame() async {
    if (_loading || _phase != _Phase.idle) return;
    setState(() => _loading = true);
    final chars  = await DataService.loadCharacters();
    final things = await ThingsDataService.loadThings();
    if (!mounted) return;
    _engine = UniversalEngine(chars, things);
    setState(() {
      _loading         = false;
      _currentQuestion = _engine!.currentQuestion;
      _answered        = false;
      _questionCount   = 0; // ilk soru → frame 33
    });
    await _exitCtrl.forward();
    if (!mounted) return;
    setState(() => _phase = _Phase.game);
    _questionCtrl.forward(from: 0);
  }

  void _onAnswer(AnswerType ans) async {
    if (_answered || _engine == null) return;
    setState(() => _answered = true);
    _engine!.answer(ans);
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    if (_engine!.shouldGuess || _engine!.isMaxReached) {
      setState(() => _phase = _Phase.result);
      _resultCtrl.forward(from: 0);
    } else {
      setState(() {
        _currentQuestion = _engine!.currentQuestion;
        _answered        = false;
        _questionCount++;  // yeni soru → diğer frame'e geç
      });
      _questionCtrl.forward(from: 0);
    }
  }

  void _playAgain() {
    _exitCtrl.reset();
    _questionCtrl.reset();
    _resultCtrl.reset();
    setState(() {
      _phase         = _Phase.idle;
      _engine        = null;
      _answered      = false;
      _loading       = false;
      _questionCount = 0;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(builder: _buildLayout),
      ),
    );
  }

  Widget _buildLayout(BuildContext ctx, BoxConstraints c) {
    final h = c.maxHeight;
    final w = c.maxWidth;

    // Game phase: cin biraz aşağıya kayıyor.
    // Görsel alt kenarı = h/4 (kutu merkezi) + cinGameOffset + h*0.31 (yarı yükseklik)
    const double cinGameFrac  = 0.035;           // aşağı kaydırma oranı
    final double cinGameOffset = h * cinGameFrac;
    final double cinGameBottom = h / 4 + cinGameOffset + h * 0.31; // ≈ h*0.595

    return Stack(
      clipBehavior: Clip.none,
      children: [

        // ── Animasyon (üst yarı, her zaman görünür) ───────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: h / 2,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Karakter animasyonu
              // idle → büyük (h*1.20) + aşağı kaydırılmış
              // game → h*0.62, hafif aşağıya kaydırılmış
              Transform.translate(
                offset: Offset(0, _phase == _Phase.game ? cinGameOffset : h * 0.15),
                child: OverflowBox(
                  alignment: Alignment.center,
                  maxWidth: double.infinity,
                  maxHeight: _phase == _Phase.game ? h * 0.62 : h * 1.20,
                  child: _CinAnimWidget(
                    staticFrameName: _phase == _Phase.game
                        ? (_questionCount.isEven
                            ? 'frame_0033-Photoroom.png'
                            : 'frame_0039-Photoroom.png')
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── BİLGECİN harfleri ─────────────────────────────────────────────────
        Positioned(
          top: h / 2 - 14, left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _exitCtrl,
            builder: (_, __) {
              if (_phase != _Phase.idle) return const SizedBox.shrink();
              final ease = Curves.easeIn.transform(_exitCtrl.value);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_letters.length, (i) => Transform.translate(
                  offset: Offset(_ldx[i] * ease, _ldy[i] * ease),
                  child: Opacity(
                    opacity: (1.0 - ease).clamp(0.0, 1.0),
                    child: Text(_letters[i],
                      style: const TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w900,
                        color: Color(0xFFFFE57F), letterSpacing: 6,
                      ),
                    ),
                  ),
                )),
              );
            },
          ),
        ),

        // Subtitle 1 → sağa uçar
        Positioned(
          top: h / 2 + 42, left: 20, right: 20,
          child: AnimatedBuilder(
            animation: _exitCtrl,
            builder: (_, __) {
              if (_phase != _Phase.idle) return const SizedBox.shrink();
              final ease = Curves.easeIn.transform(_exitCtrl.value);
              return Transform.translate(
                offset: Offset(w * ease, 0),
                child: Opacity(
                  opacity: (1.0 - ease).clamp(0.0, 1.0),
                  child: const Text(
                    'Aklından bir şey geçir, ben bulacağım.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              );
            },
          ),
        ),

        // Subtitle 2 ← sola uçar
        Positioned(
          top: h / 2 + 70, left: 20, right: 20,
          child: AnimatedBuilder(
            animation: _exitCtrl,
            builder: (_, __) {
              if (_phase != _Phase.idle) return const SizedBox.shrink();
              final ease = Curves.easeIn.transform(_exitCtrl.value);
              return Transform.translate(
                offset: Offset(-w * ease, 0),
                child: Opacity(
                  opacity: (1.0 - ease).clamp(0.0, 1.0),
                  child: const Text(
                    'Aklını okuyacağım!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.white, letterSpacing: 0.5),
                  ),
                ),
              );
            },
          ),
        ),

        // Başla butonu
        Positioned(
          top: h * 3 / 4 - 25, left: 56, right: 56,
          child: AnimatedBuilder(
            animation: _exitCtrl,
            builder: (_, __) {
              if (_phase != _Phase.idle) return const SizedBox.shrink();
              final ease = Curves.easeIn.transform(_exitCtrl.value);
              return Opacity(
                opacity: (1.0 - ease * 2.5).clamp(0.0, 1.0),
                child: SizedBox(
                  height: 50,
                  child: _loading
                      ? _loadingWidget()
                      : FilledButton(
                          onPressed: _exitCtrl.value == 0.0 ? _startGame : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kBtnColor.withOpacity(0.32),
                            side: BorderSide(color: _kBtnColor.withOpacity(0.85), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          ),
                          child: const Text('BİR ŞEY DÜŞÜNDÜM',
                            style: TextStyle(fontSize: 14, letterSpacing: 1.2,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                ),
              );
            },
          ),
        ),

        // ── Oyun: soru baloncuğu ──────────────────────────────────────────────
        if (_phase == _Phase.game)
          Positioned(
            top: cinGameBottom,
            left: 16, right: 16,
            child: FadeTransition(
              opacity: _questionFade,
              child: SlideTransition(
                position: _questionSlide,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    _currentQuestion,
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: _kTextLight, height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        // ── Oyun: cevap butonları ─────────────────────────────────────────────
        if (_phase == _Phase.game)
          Positioned(
            top: h * 3 / 4, left: 20, right: 20, bottom: 16,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [_buildAnswerButtons()],
            ),
          ),

        // ── Sonuç ─────────────────────────────────────────────────────────────
        if (_phase == _Phase.result)
          Positioned(
            top: h / 2 + 10, left: 20, right: 20, bottom: 16,
            child: _buildResultContent(),
          ),

        // Debug butonu
        if (_phase == _Phase.game && kDebugMode)
          Positioned(
            top: 4, right: 4,
            child: IconButton(
              icon: const Icon(Icons.bug_report_rounded, color: Colors.white24),
              onPressed: _showDebug,
            ),
          ),
      ],
    );
  }

  // ── Answer buttons ────────────────────────────────────────────────────────────

  Widget _buildAnswerButtons() {
    return Column(children: [
      Row(children: [
        Expanded(child: _answerBtn(AnswerType.probably)),
        const SizedBox(width: 8),
        Expanded(child: _answerBtn(AnswerType.probablyNot)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _answerBtn(AnswerType.yes)),
        const SizedBox(width: 8),
        Expanded(child: _answerBtn(AnswerType.dontKnow)),
        const SizedBox(width: 8),
        Expanded(child: _answerBtn(AnswerType.no)),
      ]),
    ]);
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
            color: _kBtnColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBtnColor.withOpacity(0.7), width: 1.2),
          ),
          child: Center(child: Text(type.label,
            style: const TextStyle(
              color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w700, letterSpacing: 0.3,
            ),
          )),
        ),
      ),
    );
  }

  // ── Result ────────────────────────────────────────────────────────────────────

  Widget _buildResultContent() {
    final guess = _engine!.bestResult;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _resultFade,
          child: ScaleTransition(
            scale: _resultScale,
            child: _buildGuessCard(guess),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 50,
          child: FilledButton.icon(
            onPressed: _playAgain,
            style: FilledButton.styleFrom(backgroundColor: _kBtnColor),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.white),
            label: const Text('YENİ TAHMİN',
              style: TextStyle(fontSize: 16, letterSpacing: 2,
                  fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildGuessCard(AnyResult guess) {
    final color = _categoryColor(guess.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), _kCardBg],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withOpacity(0.7), color.withOpacity(0.2)]),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(child: Text(
            guess.name.isNotEmpty ? guess.name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
          )),
        ),
        const SizedBox(height: 12),
        Text(
          guess.isPerson ? 'Düşündüğünüz kişi...' : 'Düşündüğünüz şey...',
          style: const TextStyle(fontSize: 13, color: _kSubtleText),
        ),
        const SizedBox(height: 4),
        Text(guess.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
              color: _kTextLight, letterSpacing: 0.5),
        ),
        if (guess.category.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.6)),
            ),
            child: Text(guess.category,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
        if (guess.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(guess.description,
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _kSubtleText),
          ),
        ],
        if (_engine!.top5Results.length > 1) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showAlternatives,
            child: Text('Diğer tahminler ›',
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  void _showAlternatives() {
    final top5 = _engine!.top5Results;
    if (top5.length <= 1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Diğer Tahminler',
            style: TextStyle(color: _kSubtleText,
                fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...top5.skip(1).map((r) {
            final c = _categoryColor(r.category);
            return Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(0.3)),
              ),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: c.withOpacity(0.2),
                  child: Text(r.name.isNotEmpty ? r.name[0] : '?',
                    style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 16))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _kTextLight)),
                  Text(r.category, style: const TextStyle(fontSize: 12, color: _kSubtleText)),
                ])),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _loadingWidget() => Container(
    decoration: BoxDecoration(
      color: _kBtnColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBtnColor)),
        SizedBox(width: 12),
        Text('Yükleniyor...', style: TextStyle(fontSize: 15, color: _kTextLight)),
      ],
    )),
  );

  void _showDebug() {
    if (_engine == null) return;
    final top = _engine!.rankedResults;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Adaylar (${_engine!.candidateCount})',
          style: const TextStyle(color: _kTextLight, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: top.length,
          itemBuilder: (_, i) {
            final e = top[i];
            final pct = (e.value * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: i == 0 ? _kBtnColor.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                  child: Center(child: Text('${i+1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: i == 0 ? _kBtnColor : Colors.white38)))),
                const SizedBox(width: 10),
                Expanded(child: Text(e.key.name,
                  style: TextStyle(fontSize: 13,
                    color: i == 0 ? _kTextLight : Colors.white54,
                    fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400))),
                Text('$pct%', style: TextStyle(fontSize: 12,
                  color: i == 0 ? _kBtnColor : Colors.white38,
                  fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kapat', style: TextStyle(color: _kBtnColor)),
      )],
    ));
  }

  Color _categoryColor(String cat) {
    if (cat.contains('Futbolcu'))                                   return const Color(0xFF22C55E);
    if (cat.contains('Müzisyen') || cat.contains('Şarkıcı'))        return const Color(0xFFEC4899);
    if (cat.contains('Rapper'))                                     return const Color(0xFF8B5CF6);
    if (cat.contains('Oyuncu'))                                     return const Color(0xFFF59E0B);
    if (cat.contains('Siyaset'))                                    return const Color(0xFF3B82F6);
    if (cat.contains('Anime'))                                      return const Color(0xFFEF4444);
    if (cat.contains('Dizi') || cat.contains('TV'))                 return const Color(0xFF06B6D4);
    if (cat.contains('Film') || cat.contains('Kurgusal'))           return const Color(0xFFFF7A00);
    if (cat.contains('Sporcu') || cat.contains('Basket')
        || cat.contains('Tenis'))                                   return const Color(0xFF10B981);
    if (cat.contains('Tarihi') || cat.contains('Osmanlı'))          return const Color(0xFFD97706);
    if (cat.contains('YouTuber'))                                   return const Color(0xFFFF0000);
    if (cat.contains('Bilim') || cat.contains('Yazar'))             return const Color(0xFF60A5FA);
    if (cat.contains('Hayvan'))                                     return const Color(0xFF84CC16);
    if (cat.contains('Yiyecek') || cat.contains('İçecek')
        || cat.contains('Bitki'))                                   return const Color(0xFFFF8C42);
    if (cat.contains('Taşıt') || cat.contains('Araç'))              return const Color(0xFF38BDF8);
    if (cat.contains('Yer') || cat.contains('Mekan')
        || cat.contains('Coğrafya'))                                return const Color(0xFF34D399);
    if (cat.contains('Dijital') || cat.contains('Uygulama')
        || cat.contains('Oyun'))                                    return const Color(0xFFA78BFA);
    if (cat.contains('Marka'))                                      return const Color(0xFFFBBF24);
    if (cat.contains('Soyut') || cat.contains('Kavram')
        || cat.contains('Duygu'))                                   return const Color(0xFFF472B6);
    if (cat.contains('Ev') || cat.contains('Mobilya')
        || cat.contains('Mutfak'))                                  return const Color(0xFF94A3B8);
    if (cat.contains('Giyim') || cat.contains('Aksesuar'))          return const Color(0xFFE879F9);
    if (cat.contains('Doğa'))                                       return const Color(0xFF4ADE80);
    if (cat.contains('Uzay'))                                       return const Color(0xFF818CF8);
    return AppTheme.accent;
  }
}

// ── Cin Animasyon Widget ──────────────────────────────────────────────────────
// Saniyede 3 kare. Belirli karelerde duraklar:
//   frame 2  → 2 sn
//   frame 12 → 3 sn
//   frame 22 → 2 sn
//   frame 35 → 6 sn
//   frame 39 → 6 sn
//   frame 42 → 6 sn
// Son kare → başa döner, sonsuz loop.
class _CinAnimWidget extends StatefulWidget {
  /// null → normal animasyon. Değer verilince o frame sabit gösterilir.
  final String? staticFrameName;
  const _CinAnimWidget({this.staticFrameName});
  @override
  State<_CinAnimWidget> createState() => _CinAnimWidgetState();
}

class _CinAnimWidgetState extends State<_CinAnimWidget> {

  // Mevcut dosyalar (küçükten büyüğe, boşluklar atlandı)
  static const _frameNames = [
    'frame_0002-Photoroom.png',
    'frame_0003-Photoroom.png',
    'frame_0004-Photoroom.png',
    'frame_0005-Photoroom.png',
    'frame_0006-Photoroom.png',
    'frame_0007-Photoroom.png',
    'frame_0008-Photoroom.png',
    'frame_0009-Photoroom.png',
    'frame_0010-Photoroom.png',
    'frame_0011-Photoroom.png',
    'frame_0012-Photoroom.png',
    'frame_0013-Photoroom.png',
    'frame_0014-Photoroom.png',
    'frame_0015-Photoroom.png',
    'frame_0016-Photoroom.png',
    'frame_0017-Photoroom.png',
    'frame_0018-Photoroom.png',
    'frame_0019-Photoroom.png',
    'frame_0020-Photoroom.png',
    'frame_0021-Photoroom.png',
    'frame_0022-Photoroom.png',
    'frame_0024-Photoroom.png',
    'frame_0025-Photoroom.png',
    'frame_0033-Photoroom.png',
    'frame_0034-Photoroom.png',
    'frame_0035-Photoroom.png',
    'frame_0036-Photoroom.png',
    'frame_0037-Photoroom.png',
    'frame_0038-Photoroom.png',
    'frame_0039-Photoroom.png',
    'frame_0042-Photoroom.png',
    'frame_0043-Photoroom.png',
    'frame_0044-Photoroom.png',
    'frame_0045-Photoroom.png',
    'frame_0046-Photoroom.png',
    'frame_0047-Photoroom.png',
    'frame_0048-Photoroom.png',
    'frame_0049-Photoroom.png',
    'frame_0050-Photoroom.png',
  ];

  // Kare numarası → duraklatma süresi (saniye)
  static const _pauseSecs = <int, int>{
    2: 2, 12: 3, 22: 2, 35: 6, 39: 6, 42: 6,
  };

  int    _index = 0;
  Timer? _timer;

  // Dosya adından kare numarasını çıkar: 'frame_0002-Photoroom.png' → 2
  static int _num(String name) => int.parse(name.substring(6, 10));

  @override
  void initState() {
    super.initState();
    if (widget.staticFrameName == null) _scheduleNext();
  }

  @override
  void didUpdateWidget(_CinAnimWidget old) {
    super.didUpdateWidget(old);
    final wasStatic = old.staticFrameName != null;
    final isStatic  = widget.staticFrameName != null;
    if (!wasStatic && isStatic) {
      // Animasyondan statik moda geçiş → timer'ı durdur
      _timer?.cancel();
    } else if (wasStatic && !isStatic) {
      // Statik moddan animasyona geri dön → yeniden başlat
      _scheduleNext();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tüm frame'leri önceden yükle (geçişlerde takılmayı önler)
    for (final name in _frameNames) {
      precacheImage(AssetImage('assets/cin_frames/$name'), context);
    }
  }

  void _scheduleNext() {
    final num   = _num(_frameNames[_index]);
    final pause = _pauseSecs[num];
    final delay = pause != null
        ? Duration(seconds: pause)
        : const Duration(milliseconds: 334); // ~3 fps

    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _frameNames.length);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.staticFrameName ?? _frameNames[_index];
    return Image.asset(
      'assets/cin_frames/$name',
      fit: BoxFit.fitHeight,   // yüksekliği doldurur, genişlik orana göre açılır
      gaplessPlayback: true,
    );
  }
}
