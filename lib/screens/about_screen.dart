import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/radii.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/morph_shape.dart';

const _repoUrl = 'https://github.com/libreAMP/kashou';
const _issuesUrl = 'https://github.com/libreAMP/kashou/issues';
const double _desktopMaxContentWidth = 640;

class _Contributor {
  final String login;
  final String avatarUrl;
  final String htmlUrl;
  final int contributions;

  const _Contributor({
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.contributions,
  });

  factory _Contributor.fromJson(Map<String, dynamic> json) {
    return _Contributor(
      login: json['login'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      htmlUrl:
          json['html_url'] as String? ?? 'https://github.com/${json['login']}',
      contributions: json['contributions'] as int? ?? 0,
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: AboutContent(),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: const BackChip(),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('About'),
      ),
      body: isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _desktopMaxContentWidth),
                child: content,
              ),
            )
          : content,
    );
  }
}

class AboutContent extends StatefulWidget {
  const AboutContent({super.key});

  @override
  State<AboutContent> createState() => _AboutContentState();
}

class _AboutContentState extends State<AboutContent> {
  static const _fallbackContributors = [
    _Contributor(
      login: 'primalkz',
      avatarUrl: 'https://avatars.githubusercontent.com/u/44187697?v=4',
      htmlUrl: 'https://github.com/primalkz',
      contributions: 172,
    ),
    _Contributor(
      login: 'PeroSar',
      avatarUrl: 'https://avatars.githubusercontent.com/u/85673786?v=4',
      htmlUrl: 'https://github.com/PeroSar',
      contributions: 3,
    ),
  ];

  String _version = '1.1.0';
  String _buildNumber = '';
  List<_Contributor> _contributors = _fallbackContributors;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _fetchContributors();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {}
  }

  Future<void> _fetchContributors() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/libreAMP/kashou/contributors'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'kashou',
        },
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        final parsed = list
            .whereType<Map<String, dynamic>>()
            .map(_Contributor.fromJson)
            .where((c) => c.login.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty && mounted) {
          setState(() => _contributors = parsed);
        }
      }
    } catch (_) {}
  }

  Widget _chip(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(rFull),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _contributorRow(BuildContext context, _Contributor c) {
    final scheme = Theme.of(context).colorScheme;
    final role = c.login.toLowerCase() == 'primalkz'
        ? 'Creator & Maintainer'
        : 'Contributor';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(rMd),
        onTap: () => launchUrl(
          Uri.parse(c.htmlUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: c.avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: c.avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                c.login.isNotEmpty
                                    ? c.login[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                              ),
                            ),
                          ),
                          errorWidget: (context, _, __) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                c.login.isNotEmpty
                                    ? c.login[0].toUpperCase()
                                    : '?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Text(
                              c.login.isNotEmpty
                                  ? c.login[0].toUpperCase()
                                  : '?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.login,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      role,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(rMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final versionText =
        _buildNumber.isNotEmpty ? 'v$_version ($_buildNumber)' : 'v$_version';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: MorphShape(
            from: MaterialShapes.cookie9Sided,
            size: 88,
            spin: true,
            color: scheme.primaryContainer,
            child: Image.asset(
              dark
                  ? 'assets/images/ka_mark_light_ink.png'
                  : 'assets/images/ka_mark_dark_ink.png',
              width: 44,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'kashou',
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(rFull),
            ),
            child: Text(
              versionText,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'your own files and all of youtube music in one player',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 28),
        Material(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(rXl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse(_repoUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 20, 14),
              child: Row(
                children: [
                  MorphShape(
                    from: MaterialShapes.sunny,
                    size: 48,
                    spin: true,
                    color: scheme.onTertiaryContainer,
                    child: Icon(
                      Icons.star_rounded,
                      color: scheme.tertiaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'star on github',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          'libreAMP/kashou',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onTertiaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: scheme.onTertiaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(rXl),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MorphShape(
                    from: MaterialShapes.clover4Leaf,
                    size: 40,
                    color: scheme.secondaryContainer,
                    child: Icon(
                      Icons.people_rounded,
                      size: 22,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Community & team',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final c in _contributors) ...[
                _contributorRow(context, c),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 2),
              _actionTile(
                context: context,
                icon: Icons.bug_report_outlined,
                title: 'Issues & feedback',
                subtitle: 'Report problems or suggest new features',
                trailing: Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => launchUrl(
                  Uri.parse(_issuesUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'kashou is free and open-source software\nlicensed under GNU GPL v3',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
