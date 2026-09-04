import 'package:flutter/material.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'utils/app_messenger.dart';
import 'utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }

  await YoutubeService.instance.initialize();

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
            settingsProvider:
                Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, audio) {
            audio?.updateSettings(settings);
            return audio ?? AudioProvider(settingsProvider: settings);
          },
        ),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
      ],
      child: _ArtSeedWatcher(
        child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightColorScheme;
              ColorScheme darkColorScheme;

              final artSeed = themeProvider.artSeed;
              final seed = themeProvider.themeSource == 'art' && artSeed != null
                  ? artSeed
                  : themeProvider.accentColor;
              if (themeProvider.themeSource == 'system' &&
                  lightDynamic != null &&
                  darkDynamic != null) {
                // reseed, the os scheme ships flat surfaces
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: _launchShift(lightDynamic.primary),
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: _launchShift(darkDynamic.primary),
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
    final art = context
        .select<AudioProvider, Uint8List?>((p) => p.currentTrack?.albumArt);
    final source =
        context.select<ThemeProvider, String>((p) => p.themeSource);
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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _showMiniPlayer = true;

  static const List<Widget> _screens = [
    StreamScreen(),
    HomeScreen(),
    LibraryScreen()
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.addListener(_onAudioProviderChange);
    });
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
    _askAllFilesAccess();
  }

  // mediastore locks our own downloads down once indexed, tags need raw write
  Future<void> _askAllFilesAccess() async {
    if (!Platform.isAndroid) return;
    const channel = MethodChannel('com.libreamp.kashou/equalizer');
    final granted =
        await channel.invokeMethod<bool>('isAllFilesAccess') ?? false;
    if (granted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('all_files_asked') == true) return;
    await prefs.setBool('all_files_asked', true);
    showToast('Grant all files access so tags and art can be saved');
    try {
      await channel.invokeMethod('openAllFilesSettings');
    } catch (_) {}
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

  // player endpoint has no author, oembed gives it without any key
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
    const ytm = YtMusicService();
    final songs = await ytm.getPlaylistSongs(list);
    if (songs.isEmpty || !mounted) return;
    final name = await ytm.getPlaylistTitle(list) ?? 'YouTube import';
    final cover = await ytm.getPlaylistThumb(list);
    if (!mounted) return;
    await Provider.of<LibraryProvider>(context, listen: false).importPlaylist(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $name')),
    );
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
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 350),
        reverseDuration: const Duration(milliseconds: 300),
      ),
      clipBehavior: Clip.none,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final topInset = mediaQuery.viewPadding.top;
        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.0,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: const [1.0],
          expand: false,
          builder: (context, scrollController) {
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
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
      bottomNavigationBar: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          if (keyboardHeight > 0) return const SizedBox.shrink();
          final route = ModalRoute.of(context);
          final isModalOpen = route != null && !route.isFirst;
          final hasPlayer =
              audioProvider.currentTrack != null && _showMiniPlayer && !isModalOpen;
          return PlayerNavBar(
            items: const [
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
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            hasPlayer: hasPlayer,
            onPlayerTap: _openNowPlaying,
            onPlayerDismiss: _dismissMiniPlayer,
          );
        },
      ),
    );
  }
}

