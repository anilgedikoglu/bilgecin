import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                  'BİLGECİN',
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
                'Aklından bir şey geçir, ben bulacağım!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.65),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 2),
              // Start button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: _loading
                      ? _loadingButton()
                      : FilledButton(
                          onPressed: _startGame,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('BİR KARAKTER DÜŞÜNDÜM',
                                  style: TextStyle(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('Aklını Okuyacağım',
                                  style: TextStyle(fontSize: 11, letterSpacing: 0.5)),
                            ],
                          ),
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
      child: ClipOval(
        child: Image.asset(
          'assets/tamuaicons.png',
          width: 140,
          height: 140,
          fit: BoxFit.cover,
        ),
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

}
