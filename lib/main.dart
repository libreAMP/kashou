import 'package:flutter/material.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'utils/app_messenger.dart';
import 'utils/now_playing_modal.dart';
import 'utils/platform.dart';
import 'utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'dart:convert';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'models/track.dart';
import 'providers/audio_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recommendation_provider.dart';
import 'services/youtube/youtube_service.dart';
import 'services/ytmusic_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stream_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/player_nav_bar.dart';

// nudge the wallpaper seed a bit each launch so it doesnt sit on one shade
final double _launchHue = Random().nextDouble() * 40 - 20;

Color _launchShift(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withHue((hsl.hue + _launchHue) % 360).toColor();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // just_audio has no desktop backend of its own, mpv fills in
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }

  await YoutubeService.instance.initialize();

  // chromecast only exists on mobile
  if (Platform.isIOS || Platform.isAndroid) {
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final GoogleCastOptions options;

    if (Platform.isIOS) {
      options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      );
    } else {
      options = GoogleCastOptionsAndroid(
        appId: appId,
      );
    }

    GoogleCastContext.instance.setSharedInstanceWithOptions(options);
  }

  // no status/nav bars to tint on desktop
  if (!isDesktop) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

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
            settingsProvider:
                Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, audio) {
            audio?.updateSettings(settings);
            return audio ?? AudioProvider(settingsProvider: settings);
          },
        ),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final rec = RecommendationProvider();
            context.read<AudioProvider>().updateRecommendationProvider(rec);
            return rec;
          },
        ),
      ],
      child: _ArtSeedWatcher(
        child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          return DynamicColorBuilder(
            // dynamic_color 2.x types its schemes from package:material_ui
            // rather than flutter/material, so the two ColorScheme types are
            // unrelated. Only the seed colour is wanted, and Color is the
            // shared dart:ui type, so read that field off the plugin's own
            // scheme and rebuild a flutter ColorScheme from it.
            builder: (dynamic lightDynamic, dynamic darkDynamic) {
              final lightPrimary = lightDynamic?.primary as Color?;
              final darkPrimary = darkDynamic?.primary as Color?;

              ColorScheme lightColorScheme;
              ColorScheme darkColorScheme;

              final artSeed = themeProvider.artSeed;
              final seed = themeProvider.themeSource == 'art' && artSeed != null
                  ? artSeed
                  : themeProvider.accentColor;
              if (themeProvider.themeSource == 'system' &&
                  lightPrimary != null &&
                  darkPrimary != null) {
                // reseed, the os scheme ships flat surfaces
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: _launchShift(lightPrimary),
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: _launchShift(darkPrimary),
                  brightness: Brightness.dark,
                );
              } else {
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                );
              }

              TextTheme getTextTheme(ColorScheme colorScheme) {
                try {
                  final fontFamily = settingsProvider.fontFamily;
                  final baseTheme =
                      ThemeData(colorScheme: colorScheme).textTheme;

                  switch (fontFamily) {
                    case 'System':
                      return baseTheme;
                    case 'Google Sans Flex':
                      return GoogleFonts.googleSansFlexTextTheme(baseTheme);
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
                navigatorKey: toastNavigatorKey,
                scaffoldMessengerKey: appMessenger,
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                theme: buildKashouTheme(
                  lightColorScheme,
                  getTextTheme(lightColorScheme),
                ),
                darkTheme: buildKashouTheme(
                  darkColorScheme,
                  getTextTheme(darkColorScheme),
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
      ),
    );
  }
}

class _ArtSeedWatcher extends StatefulWidget {
  const _ArtSeedWatcher({required this.child});

  final Widget child;

  @override
  State<_ArtSeedWatcher> createState() => _ArtSeedWatcherState();
}

class _ArtSeedWatcherState extends State<_ArtSeedWatcher> {
  Uint8List? _last;

  @override
  Widget build(BuildContext context) {
    final art = context.select<AudioProvider, Uint8List?>((p) => p.currentTrack?.albumArt);
    final source = context.select<ThemeProvider, String>((p) => p.themeSource);
    if (source == 'art' && art != null && !identical(art, _last)) {
      _last = art;
      _compute(art);
    }
    return widget.child;
  }

  Future<void> _compute(Uint8List bytes) async {
    final color = await dominantColor(bytes);
    if (color != null && mounted) {
      context.read<ThemeProvider>().setArtSeed(color);
    }
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showMiniPlayer = true;
  late final AnimationController _sheetController;
  bool get _isSheetOpen => _sheetController.value > 0.05;

  static const List<Widget> _screens = [
    StreamScreen(),
    HomeScreen(),
    LibraryScreen()
  ];

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.addListener(_onAudioProviderChange);
    });
    // deep-link intent channel only exists on the android host
    if (!isDesktop) {
      const channel = MethodChannel('com.libreamp.kashou/intent');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'link' && call.arguments is String) {
          _handleLink(call.arguments as String);
        }
        return null;
      });
      channel.invokeMethod<String>('consumeLink').then((link) {
        if (link != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleLink(link));
        }
      });
    }
  }

  void _handleLink(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final id = uri.queryParameters['v'] ?? (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null);
    final list = uri.queryParameters['list'];
    if (id != null && id.isNotEmpty) {
      setState(() => _selectedIndex = 0);
      final watch = 'https://www.youtube.com/watch?v=$id';
      Provider.of<AudioProvider>(context, listen: false).playTrack(Track(
        id: id,
        title: '',
        artist: '',
        album: '',
        path: watch,
        sourceUrl: watch,
        duration: Duration.zero,
      ));
      _fillLinkMeta(id, watch);
    } else if (list != null && list.isNotEmpty) {
      _importPlaylistLink(list);
    }
  }

  Future<void> _fillLinkMeta(String id, String watch) async {
    try {
      final resp = await http.get(Uri.parse(
          'https://www.youtube.com/oembed?url=${Uri.encodeComponent(watch)}&format=json'));
      if (resp.statusCode != 200 || !mounted) return;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final author = j['author_name'] as String? ?? '';
      final title = j['title'] as String? ?? '';
      if (author.isEmpty && title.isEmpty) return;
      final audio = Provider.of<AudioProvider>(context, listen: false);
      final current = audio.currentTrack;
      if (current == null || current.id != id) return;
      audio.updateTrackMetadata(current.copyWith(
        artist: author.isEmpty ? current.artist : author,
        title: title.isEmpty ? current.title : title,
      ));
    } catch (_) {}
  }

  Future<void> _importPlaylistLink(String list) async {
    // resolve both before the first await so neither crosses an async gap
    final library = Provider.of<LibraryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    const ytm = YtMusicService();
    final songs = await ytm.getPlaylistSongs(list);
    if (songs.isEmpty || !mounted) return;
    final name = await ytm.getPlaylistTitle(list) ?? 'YouTube import';
    final cover = await ytm.getPlaylistThumb(list);
    if (!mounted) return;
    await library.importPlaylist(
      name,
      [
        for (final s in songs)
          Track(
            id: s['id'] as String? ?? '',
            title: s['title'] as String? ?? 'Unknown',
            artist: s['channel'] as String? ?? 'Unknown',
            album: '',
            path: s['url'] as String? ?? 'https://www.youtube.com/watch?v=${s['id']}',
            sourceUrl: s['url'] as String? ?? 'https://www.youtube.com/watch?v=${s['id']}',
            duration: Duration.zero,
          ),
      ],
      coverImage: cover,
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Imported $name')),
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
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
    if (isDesktop) {
      setState(() {
        _showMiniPlayer = false;
      });
      openNowPlaying(context).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _showMiniPlayer = true;
        });
      });
      return;
    }
    _sheetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _collapseNowPlaying() {
    _sheetController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPlayerExpandDragUpdate(double dy) {
    final screenH = MediaQuery.of(context).size.height;
    if (screenH <= 0) return;
    _sheetController.value =
        (_sheetController.value - dy / screenH).clamp(0.0, 1.0);
  }

  void _onPlayerExpandDragEnd(double velocity) {
    if (velocity < -300 || _sheetController.value > 0.35) {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onNowPlayingCollapseDragUpdate(double dy) {
    final screenH = MediaQuery.of(context).size.height;
    if (screenH <= 0) return;
    _sheetController.value =
        (_sheetController.value - dy / screenH).clamp(0.0, 1.0);
  }

  void _onNowPlayingCollapseDragEnd(double velocity) {
    if (velocity > 300 || _sheetController.value < 0.65) {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static const List<NavItem> _navItems = [
    NavItem(
      Icons.music_note_outlined,
      Icons.music_note,
      'Stream',
    ),
    NavItem(Icons.folder_outlined, Icons.folder, 'Local'),
    NavItem(
      Icons.library_music_outlined,
      Icons.library_music,
      'Library',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: IndexedStack(
        key: ValueKey(_selectedIndex),
        index: _selectedIndex,
        children: _screens,
      ),
    );

    if (isDesktop) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  PlayerNavRail(
                    items: _navItems,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
            Consumer<AudioProvider>(
              builder: (context, audioProvider, child) {
                final route = ModalRoute.of(context);
                final isModalOpen = route != null && !route.isFirst;
                final hasPlayer = audioProvider.currentTrack != null &&
                    _showMiniPlayer &&
                    !isModalOpen;
                return PlayerDockBar(
                  hasPlayer: hasPlayer,
                  onPlayerTap: _openNowPlaying,
                  onPlayerDismiss: _dismissMiniPlayer,
                );
              },
            ),
          ],
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: !_isSheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sheetController.value > 0) {
          _collapseNowPlaying();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Stack(
          children: [
            body,
            AnimatedBuilder(
              animation: _sheetController,
              builder: (context, _) {
                final t = _sheetController.value;
                if (t == 0) return const SizedBox.shrink();
                final mq = MediaQuery.of(context);
                return Transform.translate(
                  offset: Offset(0, (1.0 - t) * screenHeight),
                  child: RepaintBoundary(
                    child: MediaQuery(
                      data: mq.copyWith(padding: mq.viewPadding),
                      child: SizedBox(
                        height: screenHeight,
                        width: mq.size.width,
                        child: NowPlayingScreen(
                          onCollapse: _collapseNowPlaying,
                          onCollapseDragUpdate: _onNowPlayingCollapseDragUpdate,
                          onCollapseDragEnd: _onNowPlayingCollapseDragEnd,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: _sheetController,
          builder: (context, child) {
            final t = _sheetController.value;
            if (t >= 1.0) return const SizedBox.shrink();
            return Transform.translate(
              offset: Offset(0, t * 140),
              child: Opacity(
                opacity: (1.0 - t * 2.5).clamp(0.0, 1.0),
                child: IgnorePointer(
                  ignoring: t > 0.1,
                  child: child,
                ),
              ),
            );
          },
          child: Selector<AudioProvider, bool>(
            selector: (_, audio) => audio.currentTrack != null,
            builder: (context, hasTrack, child) {
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              if (keyboardHeight > 0) return const SizedBox.shrink();
              final route = ModalRoute.of(context);
              final isModalOpen = route != null && !route.isFirst;
              final hasPlayer = hasTrack && _showMiniPlayer && !isModalOpen;
              return PlayerNavBar(
                items: _navItems,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                hasPlayer: hasPlayer,
                onPlayerTap: _openNowPlaying,
                onPlayerDismiss: _dismissMiniPlayer,
                onPlayerExpandDragUpdate: _onPlayerExpandDragUpdate,
                onPlayerExpandDragEnd: _onPlayerExpandDragEnd,
              );
            },
          ),
        ),
      ),
    );
  }
}

