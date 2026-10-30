import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../theme/shapes.dart';
import '../utils/platform.dart';
import '../widgets/morph_shape.dart';

const _repoUrl = 'https://github.com/libreAMP/kashou';

// max width of the centered content column on desktop windows
const double _kDesktopContentWidth = 600;

// minHeight keeps the Spacers honest
Widget _scrollablePage(BuildContext context, Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

Widget _title(BuildContext context, String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.05,
          ),
    );

Widget _blurb(BuildContext context, String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
    );

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _page = 0;

  late final _steps = [
    (MaterialShapes.cookie9Sided, null),
    (MaterialShapes.clover4Leaf, Icons.auto_awesome_rounded),
    (MaterialShapes.flower, Icons.palette_rounded),
    if (!isDesktop) (MaterialShapes.softBurst, Icons.lock_open_rounded),
    (MaterialShapes.sunny, Icons.favorite_rounded),
  ];

  int get _pageCount => _steps.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (!mounted) return;
    final library = Provider.of<LibraryProvider>(context, listen: false);
    await library.scanLibrary(force: true);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _go(int page) => _pageController.animateToPage(page,
      duration: EMotion.medium, curve: Curves.easeInOutCubicEmphasized);

  void _next() => _page < _pageCount - 1 ? _go(_page + 1) : _finish();

  void _previous() {
    if (_page > 0) _go(_page - 1);
  }

  // constrains and centers content on wide desktop windows; a no-op on
  // mobile so the phone layout keeps stretching edge to edge
  Widget _centered(Widget child) {
    if (!isDesktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kDesktopContentWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = SafeArea(
      child: _centered(Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 16, 0),
            child: Row(
              children: [
                _progress(scheme),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _page == _pageCount - 1 ? 0 : 1,
                  duration: EMotion.fast,
                  child:
                      TextButton(onPressed: _finish, child: const Text('skip')),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (context, c) =>
                  Center(child: _hero(math.min(c.maxHeight * 0.82, 220))),
            ),
          ),
          Expanded(
            flex: 6,
            child: PageView(
              controller: _pageController,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _scrollablePage(context, _helloPage(context)),
                _scrollablePage(context, _featuresPage(context)),
                _scrollablePage(context, _themePage(context)),
                // desktops have no runtime permission prompts,
                // so the permissions page is mobile-only
                if (!isDesktop) const _PermissionsPage(),
                _scrollablePage(context, _donePage(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _page > 0 ? 1 : 0,
                  duration: EMotion.medium,
                  curve: EMotion.emphasized,
                  child: IconButton.filledTonal(
                    onPressed: _previous,
                    tooltip: 'back',
                    iconSize: 26,
                    style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _nextButton(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      )),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      // desktop pointer users expect arrow keys to page through onboarding
      body: isDesktop
          ? CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
                const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
              },
              child: Focus(autofocus: true, child: body),
            )
          : body,
    );
  }

  Widget _hero(double size) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.primaryContainer, scheme.onPrimaryContainer),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: _pageController,
      builder: (context, _) {
        final p = _pageController.hasClients &&
                _pageController.position.hasContentDimensions
            ? _pageController.page ?? 0
            : _page.toDouble();
        final i = p.floor().clamp(0, _pageCount - 1);
        final j = math.min(i + 1, _pageCount - 1);
        final t = p - i;
        final a = colors[i % colors.length];
        final b = colors[j % colors.length];
        final fill = Color.lerp(a.$1, b.$1, t)!;
        final ink = Color.lerp(a.$2, b.$2, t)!;
        final step = _steps[p.round().clamp(0, _pageCount - 1)];
        return SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: p * math.pi / 3,
                child: Material(
                  animationDuration: Duration.zero,
                  color: fill,
                  shape: PolygonBorder(_steps[i].$1, to: _steps[j].$1, t: t),
                  child: SizedBox.square(dimension: size),
                ),
              ),
              AnimatedSwitcher(
                duration: EMotion.medium,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale:
                      CurvedAnimation(parent: anim, curve: EMotion.emphasized),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: step.$2 == null
                    ? Image.asset(
                        dark
                            ? 'assets/images/ka_mark_light_ink.png'
                            : 'assets/images/ka_mark_dark_ink.png',
                        key: const ValueKey('mark'),
                        width: size * 0.5,
                      )
                    : Icon(step.$2,
                        key: ValueKey(step.$2), size: size * 0.38, color: ink),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _progress(ColorScheme scheme) {
    return Row(
      children: [
        for (var i = 0; i < _pageCount; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _go(i),
              child: AnimatedScale(
                scale: i == _page ? 1 : 0.6,
                duration: EMotion.medium,
                curve: EMotion.emphasized,
                child: MorphShape(
                  from: _steps[i].$1,
                  size: 18,
                  spin: i == _page,
                  color: i <= _page
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _nextButton(BuildContext context) {
    final last = _page == _pageCount - 1;
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: _next,
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        child: AnimatedSize(
          duration: EMotion.medium,
          curve: EMotion.emphasized,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (last)
                const Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8, right: 10),
                    child: Text('start listening',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false),
                  ),
                ),
              SizedBox(
                width: 24,
                child: Icon(
                    last
                        ? Icons.play_arrow_rounded
                        : Icons.arrow_forward_rounded,
                    size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rFull),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _helloPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context, "hi, i'm kashou"),
        const SizedBox(height: 14),
        _blurb(
            context, 'your own files and all of youtube music in one player'),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, 'no account', scheme.primaryContainer,
                scheme.onPrimaryContainer),
            _chip(context, 'no ads', scheme.tertiaryContainer,
                scheme.onTertiaryContainer),
            _chip(context, 'open source', scheme.secondaryContainer,
                scheme.onSecondaryContainer),
          ],
        ),
      ],
    );
  }

  Widget _featuresPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final features = [
      (
        MaterialShapes.clover4Leaf,
        Icons.explore_rounded,
        'discover',
        'charts moods and mixes',
        scheme.primaryContainer,
        scheme.onPrimaryContainer
      ),
      (
        MaterialShapes.cookie6Sided,
        Icons.library_music_rounded,
        'your library',
        'local files with tags and art',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer
      ),
      (
        MaterialShapes.softBurst,
        Icons.graphic_eq_rounded,
        'studio eq',
        'ten bands to play with',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context, 'what you get'),
        const SizedBox(height: 24),
        for (final (i, f) in features.indexed)
          Transform.rotate(
            angle: (i.isEven ? -1 : 1) * 0.03,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              decoration: BoxDecoration(
                color: f.$5,
                borderRadius: BorderRadius.circular(rXl),
              ),
              child: Row(
                children: [
                  MorphShape(
                    from: f.$1,
                    size: 48,
                    color: f.$6,
                    child: Icon(f.$2, color: f.$5, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$3,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w800, color: f.$6)),
                        Text(f.$4,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: f.$6.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _themePage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final theme = context.watch<ThemeProvider>();

    Widget pick(bool on, VoidCallback onTap, Widget child) => Material(
          color: on ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(on ? rFull : rLg),
          animationDuration: EMotion.medium,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: child),
        );

    final modes = [
      (ThemeMode.light, Icons.light_mode_rounded, 'light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'dark'),
      (ThemeMode.system, Icons.brightness_auto_rounded, 'auto'),
    ];
    final sources = [
      (
        'system',
        Icons.wallpaper_rounded,
        'wallpaper',
        'colors from your phone'
      ),
      ('accent', Icons.palette_outlined, 'pick one', 'a color you choose'),
      ('art', Icons.album_rounded, 'now playing', 'follows the album art'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context, 'make it yours'),
        const SizedBox(height: 22),
        Row(
          children: [
            for (final m in modes)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: pick(
                    theme.themeMode == m.$1,
                    () => theme.setThemeMode(m.$1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(m.$2,
                              color: theme.themeMode == m.$1
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text(m.$3,
                              style: text.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: EMotion.medium,
          curve: EMotion.emphasized,
          child: theme.themeMode == ThemeMode.light
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: pick(
                    theme.pureBlack,
                    () => theme.setPureBlack(!theme.pureBlack),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.contrast_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text('pure black',
                                  style: text.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700))),
                          Switch(
                              value: theme.pureBlack,
                              onChanged: theme.setPureBlack),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        for (final c in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: pick(
              theme.themeSource == c.$1,
              () => theme.setThemeSource(c.$1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
                child: Row(
                  children: [
                    MorphShape(
                      from: MaterialShapes.circle,
                      to: MaterialShapes.cookie9Sided,
                      morphed: theme.themeSource == c.$1,
                      size: 40,
                      color: theme.themeSource == c.$1
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      child: Icon(c.$2,
                          size: 20,
                          color: theme.themeSource == c.$1
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.$3,
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(c.$4,
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _donePage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context, 'all set'),
        const SizedBox(height: 14),
        _blurb(context, 'kashou is free and open source'),
        const SizedBox(height: 24),
        Material(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(rXl),
          child: InkWell(
            borderRadius: BorderRadius.circular(rXl),
            onTap: () => launchUrl(Uri.parse(_repoUrl),
                mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MorphShape(
                    from: MaterialShapes.sunny,
                    size: 48,
                    spin: true,
                    color: scheme.onTertiaryContainer,
                    child: Icon(Icons.star_rounded,
                        color: scheme.tertiaryContainer, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('star on github',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onTertiaryContainer)),
                        Text('libreAMP/kashou',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: scheme.onTertiaryContainer
                                        .withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_outward_rounded,
                      color: scheme.onTertiaryContainer),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionsPage extends StatefulWidget {
  const _PermissionsPage();

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage>
    with WidgetsBindingObserver {
  bool _allFiles = false;
  static const _channel = MethodChannel('com.libreamp.kashou/equalizer');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAllFiles();
  }

  Future<void> _refreshAllFiles() async {
    final granted =
        await _channel.invokeMethod<bool>('isAllFilesAccess') ?? false;
    if (mounted) setState(() => _allFiles = granted);
  }

  Future<void> _openAllFiles() async {
    try {
      await _channel.invokeMethod('openAllFilesSettings');
    } catch (_) {}
  }

  final _granted = <Permission, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshAllFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Permission.audio only exists on android 13+, older devices use storage
  Future<Permission> _mediaPermission() async {
    if ((await Permission.audio.status).isPermanentlyDenied ||
        (await Permission.audio.status).isRestricted) {
      return Permission.storage;
    }
    return Permission.audio;
  }

  Future<void> _refresh() async {
    for (final p in [
      Permission.notification,
      Permission.audio,
      Permission.storage,
      Permission.bluetoothConnect
    ]) {
      final status = await p.status;
      if (!mounted) return;
      if (status.isGranted) {
        setState(() =>
            _granted[p == Permission.storage ? Permission.audio : p] = true);
      }
    }
  }

  Future<void> _request(Permission p) async {
    var target = p;
    if (p == Permission.audio) target = await _mediaPermission();
    var status = await target.request();
    if (status.isDenied && target == Permission.audio) {
      // some roms report audio as plain denied yet never show a dialog
      target = Permission.storage;
      status = await target.request();
    }
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      status = await target.status;
    }
    if (mounted) setState(() => _granted[p] = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return _scrollablePage(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(context, 'a few asks'),
          const SizedBox(height: 14),
          _blurb(context, 'you can change these later in settings'),
          const SizedBox(height: 22),
          _permissionGroup([
            (
              Icons.folder_rounded,
              'media',
              'read your local songs',
              _granted[Permission.audio] == true,
              () => _request(Permission.audio)
            ),
            (
              Icons.notifications_rounded,
              'notifications',
              'controls in the shade',
              _granted[Permission.notification] == true,
              () => _request(Permission.notification)
            ),
            (
              Icons.bluetooth_rounded,
              'bluetooth',
              'speakers and headphones',
              _granted[Permission.bluetoothConnect] == true,
              () => _request(Permission.bluetoothConnect)
            ),
            (
              Icons.edit_note_rounded,
              'all files',
              'optional, to write tags back',
              _allFiles,
              _openAllFiles
            ),
          ]),
        ],
      ),
    );
  }

  // one connected stack like the settings sections
  Widget _permissionGroup(
      List<(IconData, String, String, bool, VoidCallback)> rows) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 3),
            child: Material(
              color: rows[i].$4
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? rXl : rSm),
                bottom: Radius.circular(i == rows.length - 1 ? rXl : rSm),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: rows[i].$4 ? null : rows[i].$5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                  child: Row(
                    children: [
                      MorphShape(
                        from: MaterialShapes.circle,
                        to: MaterialShapes.cookie9Sided,
                        morphed: rows[i].$4,
                        size: 44,
                        color: rows[i].$4
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          rows[i].$4 ? Icons.check_rounded : rows[i].$1,
                          size: 22,
                          color: rows[i].$4
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rows[i].$2,
                                style: text.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(rows[i].$3,
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text(rows[i].$4 ? 'done' : 'allow',
                          style: text.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
