import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/library_provider.dart';
import '../services/permission_service.dart';
import '../services/audio_service.dart';
import '../theme/shapes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

      // welcome asks for permissions itself on first run
      if (!hasSeenWelcome) {
        Navigator.pushReplacementNamed(context, '/welcome');
        return;
      }

      await PermissionService.requestPermissions();

      await _initializeAudioService();

      // Start library scan
      final libraryProvider = Provider.of<LibraryProvider>(
        context,
        listen: false,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        await libraryProvider.scanLibrary(force: true);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _initializeAudioService() async {
    try {
      await AudioPlayerService.initialize();
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // badge spins, the ka stays upright
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: Tween(begin: -0.08, end: 0.0).animate(
                          CurvedAnimation(
                              parent: _controller,
                              curve: Curves.easeOutCubic)),
                      child: Material(
                        color: scheme.primaryContainer,
                        shape: const WavyCircleBorder(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(38),
                      child: Image.asset(
                        dark
                            ? 'assets/images/ka_mark_light_ink.png'
                            : 'assets/images/ka_mark_dark_ink.png',
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.music_note_rounded,
                          size: 64,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'kashou',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
