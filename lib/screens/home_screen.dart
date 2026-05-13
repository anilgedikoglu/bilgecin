import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/game_engine.dart';
import '../services/data_service.dart';
import 'game_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  int _highScore = 0;
  int _gamesPlayed = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('high_score') ?? 0;
      _gamesPlayed = prefs.getInt('games_played') ?? 0;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    setState(() => _loading = true);
    try {
      final characters = await DataService.loadCharacters();
      if (!mounted) return;
      final engine = GameEngine(characters);
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, b) => GameScreen(engine: engine),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      _loadStats();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A3C), Color(0xFF0F0C1E), Color(0xFF0F0C1E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo / Orb
              ScaleTransition(
                scale: _pulseAnim,
                child: _buildOrb(),
              ),
              const SizedBox(height: 28),
              // Title
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFB07FFF), Color(0xFFFFD700)],
                ).createShader(b),
                child: const Text(
                  'AKİNATÖR',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aklındaki kişiyi düşün, ben bulacağım!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.65),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 2),
              // Stats row
              if (_gamesPlayed > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statChip(Icons.emoji_events_rounded, 'En İyi', '$_highScore'),
                      const SizedBox(width: 16),
                      _statChip(Icons.gamepad_rounded, 'Oynandı', '$_gamesPlayed'),
                    ],
                  ),
                ),
              // Start button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: _loading
                      ? _loadingButton()
                      : FilledButton.icon(
                          onPressed: _startGame,
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text('OYNAMAYA BAŞLA',
                              style: TextStyle(fontSize: 16, letterSpacing: 1.5)),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Info
              TextButton(
                onPressed: _showInfoDialog,
                child: Text(
                  '50.000 karakter • Türkçe & Uluslararası',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrb() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFB07FFF), Color(0xFF6C3FC5), Color(0xFF2D1A6E)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C3FC5).withOpacity(0.7),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Icon(Icons.psychology_rounded, size: 72, color: Colors.white),
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentGold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.5))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Text('Yükleniyor...',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nasıl Oynanır?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('🧠', 'Aklında bir karakter düşün'),
            SizedBox(height: 8),
            _InfoRow('❓', 'Soruları dürüstçe cevapla'),
            SizedBox(height: 8),
            _InfoRow('✅', 'Evet / Herhalde / Bilmiyorum\nHerhalde Değil / Hayır'),
            SizedBox(height: 8),
            _InfoRow('🎯', 'Yapay zeka kişini bulmaya çalışır'),
            SizedBox(height: 8),
            _InfoRow('🏆', 'Az soruda bulursa yüksek puan!'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anladım!'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _InfoRow(this.emoji, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 14)),
        ),
      ],
    );
  }
}
