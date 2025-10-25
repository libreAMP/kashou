import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/audio_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
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

              // Get selected font family
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
                  // Fallback to default theme if font loading fails
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

  static const List<Widget> _screens = [HomeScreen(), LibraryScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
        ],
      ),
      floatingActionButton: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          if (audioProvider.currentTrack == null) {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/now-playing');
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              child: _buildMiniPlayer(audioProvider),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildMiniPlayer(AudioProvider audioProvider) {
    return Container(
      width: MediaQuery.of(context).size.width - 32,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: audioProvider.currentTrack?.albumArt != null
                  ? Image.memory(
                      audioProvider.currentTrack!.albumArt!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        );
                      },
                    )
                  : Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  audioProvider.currentTrack?.title ?? 'Unknown',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  audioProvider.currentTrack?.artist ?? 'Unknown Artist',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
            onPressed: audioProvider.togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: audioProvider.skipNext,
          ),
        ],
      ),
    );
  }
}
