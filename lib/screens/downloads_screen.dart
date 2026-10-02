import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../theme/radii.dart';
import '../utils/platform.dart';
import '../widgets/back_chip.dart';
import '../widgets/m3e_progress.dart';

// downloads list stays a single column on desktop, just centered
const double _maxContentWidth = 720;

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final scheme = Theme.of(context).colorScheme;
    final contentSliver = ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
                final jobs = manager.jobs;
                if (jobs.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 64),
                          SizedBox(height: 16),
                          Text('Nothing downloading yet'),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final job = jobs[index];
                      final busy = job.status == 'downloading' ||
                          job.status == 'queued';
                      final subtitle = job.status == 'done'
                          ? (job.artFailed ? 'Saved without album art' : 'Saved')
                          : isDesktop
                              ? 'Failed, click to retry'
                              : 'Failed, tap to retry';
                      final card = Material(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(rMd),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(rMd),
                          onTap: job.status == 'failed'
                              ? () => manager.retry(job)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  job.status == 'done'
                                      ? Icons.download_done_rounded
                                      : job.status == 'failed'
                                          ? Icons.error_outline
                                          : Icons.download_rounded,
                                  color: job.status == 'done'
                                      ? scheme.primary
                                      : job.status == 'failed'
                                          ? scheme.error
                                          : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      if (busy)
                                        job.status == 'queued'
                                            ? const M3EIndeterminateBar(
                                                height: 10)
                                            : M3EProgressBar(
                                                value: job.progress, height: 10)
                                      else
                                        Text(
                                          subtitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                                // tap-to-retry is not discoverable with a
                                // mouse, so failed jobs get a real button
                                if (isDesktop && job.status == 'failed')
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 20),
                                    tooltip: 'Retry',
                                    onPressed: () => manager.retry(job),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20),
                                  tooltip: isDesktop ? 'Remove' : null,
                                  onPressed: () => manager.remove(job),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                        child: card,
                      );
                    },
                    childCount: jobs.length,
                  ),
                );
              },
            );

    final scrollView = CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Downloads'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const BackChip(),
        ),
        contentSliver,
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
}
