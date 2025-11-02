import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'dart:io';
import 'providers/audio_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stream_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
  GoogleCastOptions? options;
  
  if (Platform.isIOS) {
    options = IOSGoogleCastOptions(
      GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
    );
  } else if (Platform.isAndroid) {
    options = GoogleCastOptionsAndroid(
      appId: appId,
    );
  }
  
  GoogleCastContext.instance.setSharedInstanceWithOptions(options!);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const KashouApp());
}

class KashouApp extends StatelessWidget {
  const KashouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, AudioProvider>(
          create: (context) => AudioProvider(
            settingsProvider: Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, audio) {
            audio?.updateSettings(settings);
            return audio ?? AudioProvider(settingsProvider: settings);
          },
        ),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightColorScheme;
              ColorScheme darkColorScheme;

              if (themeProvider.useMaterialYou &&
                  lightDynamic != null &&
                  darkDynamic != null) {
                lightColorScheme = lightDynamic.harmonized();
                darkColorScheme = darkDynamic.harmonized();
              } else {
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: themeProvider.accentColor,
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: themeProvider.accentColor,
                  brightness: Brightness.dark,
                );
              }

              TextTheme getTextTheme(ColorScheme colorScheme) {
                try {
                  final fontFamily = settingsProvider.fontFamily;
                  final baseTheme = ThemeData(colorScheme: colorScheme).textTheme;
                  
                  switch (fontFamily) {
                    case 'DM Sans':
                      return GoogleFonts.dmSansTextTheme(baseTheme);
                    case 'Manrope':
                      return GoogleFonts.manropeTextTheme(baseTheme);
                    case 'Inter':
                      return GoogleFonts.interTextTheme(baseTheme);
                    case 'Work Sans':
                      return GoogleFonts.workSansTextTheme(baseTheme);
                    case 'Roboto':
                      return GoogleFonts.robotoTextTheme(baseTheme);
                    case 'Poppins':
                      return GoogleFonts.poppinsTextTheme(baseTheme);
                    case 'Montserrat':
                      return GoogleFonts.montserratTextTheme(baseTheme);
                    case 'Lato':
                      return GoogleFonts.latoTextTheme(baseTheme);
                    case 'Nunito':
                      return GoogleFonts.nunitoTextTheme(baseTheme);
                    case 'Open Sans':
                      return GoogleFonts.openSansTextTheme(baseTheme);
                    case 'Raleway':
                      return GoogleFonts.ralewayTextTheme(baseTheme);
                    case 'Quicksand':
                      return GoogleFonts.quicksandTextTheme(baseTheme);
                    case 'Ubuntu':
                      return GoogleFonts.ubuntuTextTheme(baseTheme);
                    case 'Source Sans Pro':
                      return GoogleFonts.openSansTextTheme(baseTheme);
                    case 'Playfair Display':
                      return GoogleFonts.playfairDisplayTextTheme(baseTheme);
                    case 'Merriweather':
                      return GoogleFonts.merriweatherTextTheme(baseTheme);
                    case 'Oswald':
                      return GoogleFonts.oswaldTextTheme(baseTheme);
                    case 'Bebas Neue':
                      return GoogleFonts.bebasNeueTextTheme(baseTheme);
                    case 'Pacifico':
                      return GoogleFonts.pacificoTextTheme(baseTheme);
                    case 'Lobster':
                      return GoogleFonts.lobsterTextTheme(baseTheme);
                    default:
                      return baseTheme;
                  }
                } catch (e) {
                  return ThemeData(colorScheme: colorScheme).textTheme;
                }
              }

              return MaterialApp(
                title: 'Kashou',
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                theme: ThemeData(
                  useMaterial3: true,
                  colorScheme: lightColorScheme,
                  textTheme: getTextTheme(lightColorScheme),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  colorScheme: darkColorScheme,
                  textTheme: getTextTheme(darkColorScheme),
                ),
                home: const SplashScreen(),
                routes: {
                  '/welcome': (context) => const WelcomeScreen(),
                  '/home': (context) => const MainNavigationScreen(),
                  '/now-playing': (context) => const NowPlayingScreen(),
                  '/settings': (context) => const SettingsScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _showMiniPlayer = true;

  static const List<Widget> _screens = [HomeScreen(), LibraryScreen(), StreamScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.addListener(_onAudioProviderChange);
    });
  }

  @override
  void dispose() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.removeListener(_onAudioProviderChange);
    super.dispose();
  }

  void _onAudioProviderChange() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    if (audioProvider.currentTrack != null && !_showMiniPlayer) {
      setState(() {
        _showMiniPlayer = true;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _dismissMiniPlayer() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.stop();
    setState(() {
      _showMiniPlayer = false;
    });
  }

  void _openNowPlaying() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final primaryCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );

          final slideAnimation = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(primaryCurve);
          final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(primaryCurve);

          return SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      ),
    ).then((_) {
      setState(() {
        _showMiniPlayer = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: IndexedStack(
          key: ValueKey(_selectedIndex),
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Stream',
          ),
        ],
      ),
      floatingActionButton: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final route = ModalRoute.of(context);
          final isModalOpen = route != null && !route.isFirst;
          final hasPlayer = audioProvider.currentTrack != null && _showMiniPlayer;

          if (!hasPlayer || keyboardHeight > 0 || isModalOpen) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 90),
            child: MiniPlayer(
              onTap: _openNowPlaying,
              onDismiss: _dismissMiniPlayer,
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

}
