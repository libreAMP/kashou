import 'dart:io';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';
import '../services/download_store.dart';
import '../services/youtube/youtube_service.dart';
import '../services/ytdl_service.dart';
import '../utils/toast.dart';

class DownloadJob {
  DownloadJob({required this.track, this.thumbUrl});

  final Track track;
  final String? thumbUrl;
  String get id => track.sourceUrl ?? track.path;
  double progress = 0;
  String status = 'queued';
  bool artFailed = false;
}

class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final List<DownloadJob> jobs = [];
  bool _busy = false;

  void enqueue(Track track, {String? thumbUrl}) {
    final id = track.sourceUrl ?? track.path;
    if (jobs.any((j) => j.id == id && j.status != 'failed')) return;
    jobs.insert(0, DownloadJob(track: track, thumbUrl: thumbUrl));
    notifyListeners();
    _pump();
  }

  void retry(DownloadJob job) {
    job.status = 'queued';
    job.progress = 0;
    notifyListeners();
    _pump();
  }

  void remove(DownloadJob job) {
    if (job.status == 'downloading') return;
    jobs.remove(job);
    notifyListeners();
  }

  void _pump() {
    if (_busy) return;
    DownloadJob? next;
    for (final j in jobs) {
      if (j.status == 'queued') {
        next = j;
        break;
      }
    }
    if (next == null) return;
    _busy = true;
    final job = next;
    job.status = 'downloading';
    notifyListeners();
    _run(job).then((_) {
      job.status = 'done';
      showToast(job.artFailed
          ? 'Audio saved, album art extraction failed'
          : 'Saved ${job.track.title}');
    }).catchError((e) {
      job.status = 'failed';
      showToast('Download failed: ${job.track.title}');
    }).whenComplete(() {
      _busy = false;
      notifyListeners();
      _pump();
    });
  }

  Future<void> _run(DownloadJob job) async {
    const ytdlService = YtdlWrapperService();
    final track = job.track;
    final uri = Uri.tryParse(track.sourceUrl ?? track.path);
    final vid = uri?.queryParameters['v'] ??
        (uri != null && uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null);
    if (vid == null) throw Exception('Not a youtube track');

    final info = await YoutubeService.instance.fetchStreams(vid);
    if (info == null || info.audioStreams.isEmpty) {
      throw Exception('No audio streams');
    }

    // opus usually wins on bitrate and its container keeps pictures
    final streams = List.of(info.audioStreams)
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    final stream = streams.first;

    final safeTitle = info.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final safeArtist = track.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final ext = stream.mimeType.contains('webm') ? '.opus' : '.m4a';
    final filename = '$safeTitle - $safeArtist$ext';

    final downloadDir = await DownloadStore.dir();
    final filePath = '${downloadDir.path}/$filename';
    final file = File(filePath);

    if (stream.url.contains('.m3u8')) {
      await _hls(stream.url, file, job);
    } else {
      await _direct(stream.url, file, job);
    }

    await DownloadStore.rememberArt(filePath, vid);

    Uint8List? art;
    try {
      art = track.albumArt ??
          await ytdlService.fetchVideoArt(vid, preferred: job.thumbUrl);
    } catch (_) {}
    job.artFailed = art == null;

    // tags so the file stands on its own offline
    try {
      await AudioTags.write(
        filePath,
        Tag(
          title: info.title,
          trackArtist: track.artist,
          album: track.artist,
          pictures: [
            if (art != null)
              Picture(
                bytes: art,
                mimeType: MimeType.jpeg,
                pictureType: PictureType.coverFront,
              ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[Download] tagging failed: $e');
    }
  }

  Future<void> _hls(String playlistUrl, File outputFile, DownloadJob job) async {
    final client = http.Client();
    try {
      final playlistResponse = await client.get(Uri.parse(playlistUrl));
      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to download playlist');
      }

      final segmentUrls = <String>[];
      for (final line in playlistResponse.body.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('#') &&
            (trimmed.endsWith('.ts') ||
                trimmed.endsWith('.aac') ||
                trimmed.endsWith('.mp4'))) {
          segmentUrls.add(trimmed.startsWith('http')
              ? trimmed
              : Uri.parse(playlistUrl).resolve(trimmed).toString());
        }
      }
      if (segmentUrls.isEmpty) {
        throw Exception('No segments in playlist');
      }

      final sink = outputFile.openWrite();
      var done = 0;
      try {
        for (final segmentUrl in segmentUrls) {
          final segment = await client.get(Uri.parse(segmentUrl));
          if (segment.statusCode == 200) {
            sink.add(segment.bodyBytes);
          }
          done++;
          job.progress = (done / segmentUrls.length).clamp(0.0, 1.0);
          notifyListeners();
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _direct(String fileUrl, File outputFile, DownloadJob job) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(fileUrl));
      request.headers['User-Agent'] = 'Mozilla/5.0';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final sink = outputFile.openWrite();
      // partial files stay, retry overwrites them
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          if (contentLength > 0) {
            job.progress = (downloadedBytes / contentLength).clamp(0.0, 1.0);
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }
}
