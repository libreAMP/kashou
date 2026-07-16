import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/library_provider.dart';
import '../theme/radii.dart';
import '../theme/shapes.dart';

const _repoUrl = 'https://github.com/libreAMP/kashou';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pageCount = 4;

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

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  // lowercase display type is the kashou voice, not a typo
  TextStyle? _displayStyle(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          height: 1.02,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _brandPage(context),
                  _featuresPage(context),
                  const _PermissionsPage(),
                  _connectPage(context),
                ],
              ),
            ),
            _dots(scheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut),
                      child: const Text('back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 16)),
                    child: Text(last ? 'start listening' : 'next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pageCount, (i) {
          final active = i == _page;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _mark(BuildContext context, double size) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.primaryContainer,
      shape: const WavyCircleBorder(),
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.24),
          child: Image.asset(
            dark
                ? 'assets/images/ka_mark_light_ink.png'
                : 'assets/images/ka_mark_dark_ink.png',
          ),
        ),
      ),
    );
  }

  Widget _brandPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          _mark(context, 148),
          const SizedBox(height: 28),
          Text('kashou', style: _displayStyle(context)?.copyWith(
                color: scheme.primary,
                fontSize: 56,
              )),
          const SizedBox(height: 12),
          Text(
            'your files and the whole of youtube music, one player, no account',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'free and open source, gpl 3.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _featuresPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final features = [
      ('discover', 'real youtube music charts, playlists and moods'),
      ('your library', 'local files with tags, albums and artists'),
      ('studio eq', 'a 10 band equalizer and audio effects'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text('everything in\none place', style: _displayStyle(context)),
          const SizedBox(height: 40),
          for (final (i, f) in features.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0${i + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$1,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(f.$2,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _connectPage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text('built in the\nopen', style: _displayStyle(context)),
          const SizedBox(height: 14),
          Text(
            'kashou is free software, star the repo to follow along',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 32),
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(rMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(rMd),
              onTap: () => launchUrl(Uri.parse(_repoUrl),
                  mode: LaunchMode.externalApplication),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.star_border_rounded),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Star on GitHub',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('github.com/libreAMP/kashou'),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_outward_rounded),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatefulWidget {
  const _PermissionsPage();

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> {
  final _granted = <Permission, bool>{};

  @override
  void initState() {
    super.initState();
    _refresh();
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
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (Permission.audio, Icons.folder_outlined, 'media & storage',
          'read your local audio files'),
      (Permission.notification, Icons.notifications_none_rounded,
          'notifications', 'playback controls in the shade'),
      (Permission.bluetoothConnect, Icons.bluetooth_rounded, 'bluetooth',
          'nearby speakers and headphones'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'before you\nstart',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'grant what you want now, everything also works from settings later',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 30),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(rMd),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(item.$2, color: scheme.onSurfaceVariant, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$3,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(item.$4,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _granted[item.$1] == true
                          ? Icon(Icons.check_circle_rounded,
                              color: scheme.primary, size: 26)
                          : FilledButton.tonal(
                              onPressed: () => _request(item.$1),
                              child: const Text('allow'),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
