import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../utils/platform.dart';
import '../widgets/m3e_search.dart';
import '../widgets/track_list_item.dart';
import '../widgets/track_options_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final docked = MediaQuery.sizeOf(context).width >= 600;
    final maxWidth = docked ? 720.0 : double.infinity;

    final field = M3ESearchBar(
      controller: _searchController,
      focusNode: _focusNode,
      docked: docked,
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
      onBack: () => Navigator.of(context).pop(),
    );

    final results = M3ESearchResults(
      docked: docked,
      child: _buildResults(context),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [field, Expanded(child: results)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        if (_searchQuery.isEmpty) {
          return _empty(
            context,
            Icons.search_rounded,
            'Search for songs',
          );
        }

        final results = library.searchTracks(_searchQuery);
        if (results.isEmpty) {
          return _empty(
            context,
            Icons.search_off_rounded,
            'No results found',
            subtitle: 'Try a different search term',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length,
          itemBuilder: (context, index) {
            Widget item = TrackListItem(track: results[index]);
            if (isDesktop) {
              item = GestureDetector(
                behavior: HitTestBehavior.translucent,
                onSecondaryTapUp: (_) =>
                    showTrackOptionsSheet(context, results[index]),
                child: item,
              );
            }
            return M3ESearchStagger(index: index, child: item);
          },
        );
      },
    );
  }

  Widget _empty(BuildContext context, IconData icon, String title,
      {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
