import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../services/download_manager.dart';
import '../theme/app_theme.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/empty_shape.dart';
import '../widgets/m3e_progress.dart';
import '../widgets/morph_shape.dart';
import '../widgets/square_art.dart';

// downloads list stays a single column on desktop, just centered
const double _maxContentWidth = 720;

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final scheme = Theme.of(context).colorScheme;

    final scrollView = ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final jobs = manager.jobs;
        int count(bool Function(DownloadJob) test) => jobs.where(test).length;
        final saving = count((j) => j.status != 'done' && j.status != 'failed');
        final saved = count((j) => j.status == 'done');
        final failed = count((j) => j.status == 'failed');

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Downloads'),
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: const BackChip(),
            ),
            if (jobs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyShape(
                  icon: Icons.download_rounded,
                  title: 'nothing here yet',
                  body: 'songs you download show up here',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (saving > 0)
                        _pill(context, '$saving saving',
                            scheme.primaryContainer, scheme.onPrimaryContainer),
                      if (saved > 0)
                        _pill(
                            context,
                            '$saved saved',
                            scheme.secondaryContainer,
                            scheme.onSecondaryContainer),
                      if (failed > 0)
                        _pill(context, '$failed failed', scheme.errorContainer,
                            scheme.onErrorContainer),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: jobs.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _JobCard(job: jobs[i]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );

    if (!isDesktop) return Scaffold(body: scrollView);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: scrollView,
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, Color bg, Color fg) {
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
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final DownloadJob job;

  String? get _thumb {
    if (job.thumbUrl != null) return job.thumbUrl;
    final v = Uri.tryParse(job.track.sourceUrl ?? job.track.path)
        ?.queryParameters['v'];
    return v == null ? null : 'https://i.ytimg.com/vi/$v/mqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = job.status == 'done';
    final failed = job.status == 'failed';
    final queued = job.status == 'queued';
    final busy = !done && !failed;
    final pct = (job.progress * 100).round();

    final status = done
        ? (job.artFailed ? 'saved without art' : 'saved')
        : failed
            ? (isDesktop ? 'failed, click to retry' : 'failed, tap to retry')
            : queued
                ? 'waiting in line'
                : 'saving';

    return Material(
      color: failed
          ? scheme.errorContainer.withValues(alpha: 0.5)
          : done
              ? scheme.surfaceContainerLow
              : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(rXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: failed ? () => manager.retry(job) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MorphShape(
                      from: MaterialShapes.square,
                      to: MaterialShapes.cookie9Sided,
                      morphed: busy,
                      spin: job.status == 'downloading',
                      size: 64,
                      child: SquareArt(
                          url: _thumb,
                          bytes: job.track.albumArt,
                          size: 64,
                          radius: 0),
                    ),
                    if (done || failed)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: MorphShape(
                          from: MaterialShapes.cookie4Sided,
                          size: 24,
                          color: failed ? scheme.error : scheme.primary,
                          child: Icon(
                              failed
                                  ? Icons.priority_high_rounded
                                  : Icons.check_rounded,
                              size: 15,
                              color:
                                  failed ? scheme.onError : scheme.onPrimary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(job.track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: busy
                              ? (queued
                                  ? const M3EIndeterminateBar(height: 8)
                                  : M3EProgressBar(
                                      value: job.progress, height: 8))
                              : Text(status,
                                  style: text.labelMedium?.copyWith(
                                      color: failed
                                          ? scheme.error
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600)),
                        ),
                        if (busy) ...[
                          const SizedBox(width: 10),
                          AnimatedSwitcher(
                            duration: EMotion.fast,
                            child: Text(queued ? 'next' : '$pct%',
                                key: ValueKey(queued ? -1 : pct),
                                style: text.labelLarge?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isDesktop && failed)
                // tap-to-retry is not discoverable with mouse so failed jobs get a button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Retry',
                  onPressed: () => manager.retry(job),
                ),
              if (job.status != 'downloading')
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: isDesktop ? 'Remove' : null,
                  onPressed: () => manager.remove(job),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
