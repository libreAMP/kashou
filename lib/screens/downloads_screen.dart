import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../theme/radii.dart';
import '../widgets/back_chip.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = DownloadManager.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Downloads'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: const BackChip(),
          ),
          ListenableBuilder(
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
    final busy = job.status == 'downloading' || job.status == 'queued';
                    final subtitle = job.status == 'done'
                        ? (job.artFailed ? 'Saved without album art' : 'Saved')
                        : 'Failed, tap to retry';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                      child: Material(
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
                                        LinearProgressIndicator(
                                          value: job.status == 'queued'
                                              ? null
                                              : job.progress,
                                          minHeight: 3,
                                        )
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
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20),
                                  onPressed: () => manager.remove(job),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: jobs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

