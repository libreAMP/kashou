import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/loading_indicator.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../utils/platform.dart';

class MetadataEditorScreen extends StatefulWidget {
  final Track track;

  const MetadataEditorScreen({super.key, required this.track});

  @override
  State<MetadataEditorScreen> createState() => _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends State<MetadataEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _albumArtistController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackNumberController;
  late TextEditingController _commentController;

  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isEditable = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album);
    _albumArtistController = TextEditingController(text: widget.track.artist);
    _genreController = TextEditingController(text: widget.track.genre ?? '');
    _yearController = TextEditingController(
      text: widget.track.year?.toString() ?? '',
    );
    _trackNumberController = TextEditingController(
      text: widget.track.trackNumber?.toString() ?? '',
    );
    _commentController = TextEditingController();

    final source = widget.track.sourceUrl ?? widget.track.path;
    _isEditable = !source.startsWith('http');

    // Add listeners to detect changes
    _titleController.addListener(_onFieldChanged);
    _artistController.addListener(_onFieldChanged);
    _albumController.addListener(_onFieldChanged);
    _albumArtistController.addListener(_onFieldChanged);
    _genreController.addListener(_onFieldChanged);
    _yearController.addListener(_onFieldChanged);
    _trackNumberController.addListener(_onFieldChanged);
    _commentController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _albumArtistController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackNumberController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // PopScope replacement for the old WillPopScope gate: confirm with the user
  // before dropping unsaved edits.
  Future<void> _confirmPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (result == true && mounted) Navigator.pop(context);
  }

  Future<void> _saveMetadata() async {
    if (!_isEditable || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final updatedTrack = await _writeTags();
      if (!mounted) return;

      final library = context.read<LibraryProvider>();
      final audio = context.read<AudioProvider>();
      library.updateTrackMetadata(updatedTrack);
      audio.updateTrackMetadata(updatedTrack);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadata saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save metadata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<Track> _writeTags() async {
    final path = widget.track.path;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found on disk');
    }

    Tag? existing;
    try {
      existing = await AudioTags.read(path);
    } catch (_) {
      existing = const Tag(pictures: []);
    }

    final updatedTag = Tag(
      title: _titleController.text.trim(),
      trackArtist: _artistController.text.trim(),
      album: _albumController.text.trim(),
      albumArtist: _albumArtistController.text.trim(),
      genre: _genreController.text.trim().isEmpty
          ? null
          : _genreController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      trackNumber: int.tryParse(_trackNumberController.text.trim()),
      trackTotal: existing?.trackTotal,
      discNumber: existing?.discNumber,
      discTotal: existing?.discTotal,
      duration: existing?.duration,
      pictures: existing?.pictures ?? const [],
    );

    try {
      await AudioTags.write(path, updatedTag);
    } catch (e) {
      throw Exception('Tag writing failed: $e');
    }

    return widget.track.copyWith(
      title: _titleController.text.trim(),
      artist: _artistController.text.trim(),
      album: _albumController.text.trim(),
      genre: _genreController.text.trim().isEmpty
          ? null
          : _genreController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      trackNumber: int.tryParse(_trackNumberController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = LayoutBuilder(
      builder: (context, constraints) {
        // on wide desktop windows, center the form at a readable width and
        // lay fields out in two columns instead of one long phone list
        final twoColumns = isDesktop && constraints.maxWidth >= 720;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: twoColumns ? 800 : double.infinity,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _buildFormChildren(context, twoColumns),
            ),
          ),
        );
      },
    );

    if (isDesktop) {
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (_hasChanges && _isEditable && !_isSaving) {
              _saveMetadata();
            }
          },
        },
        child: Focus(autofocus: true, child: body),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Metadata'),
          actions: [
            if (_hasChanges && _isEditable)
              TextButton(
                onPressed: _isSaving ? null : _saveMetadata,
                child: _isSaving
                    ? KashouLoader(
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Text(
                        'SAVE',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  List<Widget> _buildFormChildren(BuildContext context, bool twoColumns) {
    final basicInfoFields = [
      _buildEditableField(
        controller: _titleController,
        label: 'Title',
        icon: Icons.music_note,
      ),
      _buildEditableField(
        controller: _artistController,
        label: 'Artist',
        icon: Icons.person,
      ),
      _buildEditableField(
        controller: _albumController,
        label: 'Album',
        icon: Icons.album,
      ),
      _buildEditableField(
        controller: _albumArtistController,
        label: 'Album Artist',
        icon: Icons.people,
      ),
    ];

    final additionalInfoFields = [
      Row(
        children: [
          Expanded(
            child: _buildEditableField(
              controller: _yearController,
              label: 'Year',
              icon: Icons.calendar_today,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildEditableField(
              controller: _trackNumberController,
              label: 'Track #',
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      _buildEditableField(
        controller: _genreController,
        label: 'Genre',
        icon: Icons.category,
      ),
      _buildEditableField(
        controller: _commentController,
        label: 'Comment',
        icon: Icons.comment,
        maxLines: 3,
      ),
    ];

    final fileInfoCards = [
      _buildInfoCard(
        'File Path',
        widget.track.path,
        Icons.folder,
      ),
      _buildInfoCard(
        'Format',
        widget.track.codec ?? 'Unknown',
        Icons.audio_file,
      ),
      _buildInfoCard(
        'Bitrate',
        widget.track.bitrate != null
            ? '${widget.track.bitrate} kbps'
            : 'Unknown',
        Icons.speed,
      ),
      _buildInfoCard(
        'Sample Rate',
        widget.track.sampleRate != null
            ? '${widget.track.sampleRate} Hz'
            : 'Unknown',
        Icons.graphic_eq,
      ),
      _buildInfoCard(
        'Duration',
        _formatDuration(widget.track.duration),
        Icons.timer,
      ),
    ];

    return [
      // Album Art Section
      Center(
        child: Stack(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: widget.track.albumArt != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        widget.track.albumArt!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.music_note,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: FloatingActionButton.small(
                onPressed: _isEditable
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select album art from gallery'),
                          ),
                        );
                      }
                    : null,
                tooltip: isDesktop ? 'Edit album art' : null,
                child: const Icon(Icons.edit),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      // Basic Info Section
      Text(
        'Basic Information',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 16),
      _buildFieldGroup(basicInfoFields, twoColumns),
      const SizedBox(height: 32),

      // Additional Info Section
      Text(
        'Additional Information',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 16),
      _buildFieldGroup(additionalInfoFields, twoColumns),
      const SizedBox(height: 32),

      // File Info Section (Read-only)
      Text(
        'File Information',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      const SizedBox(height: 16),
      _buildFieldGroup(fileInfoCards, twoColumns, spacing: 8),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildFieldGroup(
    List<Widget> items,
    bool twoColumns, {
    double spacing = 16,
  }) {
    if (twoColumns) {
      final rows = <Widget>[];
      for (var i = 0; i < items.length; i += 2) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: items[i]),
              if (i + 1 < items.length) ...[
                const SizedBox(width: 16),
                Expanded(child: items[i + 1]),
              ],
            ],
          ),
        );
        if (i + 2 < items.length) rows.add(SizedBox(height: spacing));
      }
      return Column(children: rows);
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i + 1 < items.length) SizedBox(height: spacing),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    if (_isEditable) {
      return _buildTextField(
        controller: controller,
        label: label,
        icon: icon,
        keyboardType: keyboardType,
        maxLines: maxLines,
      );
    }

    return _DisabledField(
      label: label,
      icon: icon,
      value: controller.text,
      maxLines: maxLines,
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }
}

class _DisabledField extends StatefulWidget {
  const _DisabledField({
    required this.label,
    required this.icon,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final IconData icon;
  final String value;
  final int maxLines;

  @override
  State<_DisabledField> createState() => _DisabledFieldState();
}

class _DisabledFieldState extends State<_DisabledField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value.isEmpty ? 'Not available' : widget.value,
    );
  }

  @override
  void didUpdateWidget(_DisabledField old) {
    super.didUpdateWidget(old);
    final next = widget.value.isEmpty ? 'Not available' : widget.value;
    if (next != _controller.text) _controller.text = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    final radius = BorderRadius.circular(12);

    return TextField(
      controller: _controller,
      enabled: false,
      style:
          theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: theme.textTheme.labelMedium?.copyWith(color: muted),
        prefixIcon: Icon(widget.icon, color: muted),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      maxLines: widget.maxLines,
    );
  }
}
