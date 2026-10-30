// lib/core/job_media_widgets.dart
// Photo strip and voice-note player for request media (Cloudinary URLs).
// IDENTICAL in both apps.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'cloudinary.dart';

/// Horizontal strip of photos. Tap one to view it full screen.
class PhotoStrip extends StatelessWidget {
  final List<String> urls;
  final double size;
  const PhotoStrip({super.key, required this.urls, this.size = 84});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _PhotoViewer(urls: urls, initial: i),
          )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: Cloudinary.thumb(urls[i]),
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFF3F4F6),
                child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final List<String> urls;
  final int initial;
  const _PhotoViewer({required this.urls, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays a voice note from a URL, or from a local file (preview before upload).
class VoiceNotePlayer extends StatefulWidget {
  final String? url;
  final String? localFilePath;
  final Color color;
  const VoiceNotePlayer({super.key, this.url, this.localFilePath, this.color = const Color(0xFF7C3AED)})
      : assert(url != null || localFilePath != null);

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = Duration.zero);
    }));
  }

  @override
  void didUpdateWidget(covariant VoiceNotePlayer old) {
    super.didUpdateWidget(old);
    if (old.localFilePath != widget.localFilePath || old.url != widget.url) {
      _player.stop();
      _pos = Duration.zero;
      _dur = Duration.zero;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (widget.localFilePath != null) {
        await _player.play(DeviceFileSource(widget.localFilePath!));
      } else {
        await _player.play(UrlSource(widget.url!));
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) => '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final total = _dur.inMilliseconds == 0 ? 1 : _dur.inMilliseconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        IconButton(
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
              : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.color, size: 34),
        ),
        Expanded(
          child: _error
              ? const Text('Could not play voice note', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))
              : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_pos.inMilliseconds / total).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: widget.color.withValues(alpha: 0.15),
              color: widget.color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(_fmt(playing || _pos > Duration.zero ? _pos : _dur),
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(width: 6),
      ]),
    );
  }
}