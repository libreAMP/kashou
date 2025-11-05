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
    setState(() {
      _showMiniPlayer = false;
    });
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final topInset = mediaQuery.viewPadding.top;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            top: topInset,
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: const NowPlayingScreen(),
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _showMiniPlayer = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: colorScheme.secondaryContainer.withOpacity(0.9),
          iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((states) {
            final onSurface = colorScheme.onSurfaceVariant;
            final onSelected = colorScheme.onSecondaryContainer;
            return IconThemeData(
              color: states.contains(MaterialState.selected) ? onSelected : onSurface,
              size: states.contains(MaterialState.selected) ? 26 : 24,
            );
          }),
          labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>((states) {
            final base = theme.textTheme.labelMedium;
            if (base == null) return const TextStyle();
            return states.contains(MaterialState.selected)
                ? base.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  )
                : base.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  );
          }),
        ),
        child: NavigationBar(
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

class BottomNavDestination {
  const BottomNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class AnimatedBottomNavBar extends StatefulWidget {
  const AnimatedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<BottomNavDestination> destinations;

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.destinations.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 100),
        vsync: this,
      ),
    );
    _scales = _controllers.map((controller) => Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    )).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTap(int index) {
    _controllers[index].forward().then((_) {
      _controllers[index].reverse();
    });
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.destinations.length, (index) {
          final destination = widget.destinations[index];
          final isSelected = index == widget.selectedIndex;

          return Expanded(
            child: InkWell(
              onTap: () => _onTap(index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedBuilder(
                animation: _scales[index],
                builder: (context, child) => Transform.scale(
                  scale: _scales[index].value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: isSelected
                        ? BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? destination.selectedIcon : destination.icon,
                          color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
