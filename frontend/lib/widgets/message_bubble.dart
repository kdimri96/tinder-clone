import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/app_config.dart';
import '../utils/app_theme.dart';
import '../widgets/network_image_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showTime;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    this.showTime = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [_buildContent(context)],
          ),
          if (showTime) ...[
            const SizedBox(height: 4),
            _buildTimestamp(context),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isAudio) {
      return _AudioBubble(message: message, isMine: isMine);
    }
    if (message.isSnapMessage) {
      return _SnapBubble(message: message, isMine: isMine);
    }
    if (message.isPhoto) {
      return _PhotoBubble(
        mediaUrl: message.mediaUrl!,
        isMine: isMine,
        onTap: () => _showFullImage(context, message.mediaUrl!),
      );
    }
    // Plain text
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMine ? null : AppTheme.surface2,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 20),
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: isMine ? Colors.white : AppTheme.textDark,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id ?? '';
    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text(
          DateFormat.jm().format(message.createdAt.toLocal()),
          style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          // Snap status
          if (message.isSnapMessage) ...[
            Text(
              message.snapViewedBy.any((id) => id != myId)
                  ? 'Opened'
                  : 'Delivered',
              style: TextStyle(
                color: message.snapViewedBy.any((id) => id != myId)
                    ? AppTheme.error
                    : AppTheme.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Icon(
              message.readBy.length > 1 ? Icons.done_all : Icons.done,
              size: 14,
              color: message.readBy.length > 1
                  ? AppTheme.accent
                  : AppTheme.textLight,
            ),
          ],
        ],
      ],
    );
  }

  void _showFullImage(BuildContext context, String mediaUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: InteractiveViewer(
              child: NetworkImageWidget(imageUrl: mediaUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Audio Bubble ─────────────────────────────────────────────────────────────

class _AudioBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  const _AudioBubble({required this.message, required this.isMine});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  static const int _barCount = 28;

  // Pseudo-random bar heights seeded by the message ID — stable across rebuilds
  late final List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    final seed = widget.message.id.hashCode;
    final rng = Random(seed);
    _barHeights =
        List.generate(_barCount, (_) => 0.2 + rng.nextDouble() * 0.8);

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      final url = widget.message.mediaUrl ?? '';
      final fullUrl = url.startsWith('http')
          ? url
          : '${AppConfig.mediaBaseUrl}$url';
      await _player.play(UrlSource(fullUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSecs = widget.message.audioDuration ?? _total.inSeconds;
    final progressFraction = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final played = (_barCount * progressFraction).round();

    final bg = widget.isMine ? AppTheme.primary : AppTheme.surface2;
    final fg = widget.isMine ? Colors.white : AppTheme.primary;
    final fgDim = widget.isMine
        ? Colors.white.withOpacity(0.45)
        : AppTheme.primary.withOpacity(0.3);

    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isMine ? 20 : 4),
          bottomRight: Radius.circular(widget.isMine ? 4 : 20),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withOpacity(0.15),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: fg,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform bars
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_barCount, (i) {
                      final isPlayed = i < played;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 2.5,
                        height: 28 * _barHeights[i],
                        decoration: BoxDecoration(
                          color: isPlayed ? fg : fgDim,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _playing ? _fmt(_position) : _fmt(Duration(seconds: totalSecs)),
                  style: TextStyle(
                    color: fg.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Snap Bubble ──────────────────────────────────────────────────────────────

class _SnapBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  const _SnapBubble({required this.message, required this.isMine});

  @override
  State<_SnapBubble> createState() => _SnapBubbleState();
}

class _SnapBubbleState extends State<_SnapBubble> {
  bool _viewing = false;

  bool _alreadyOpened(String myId) =>
      widget.message.snapViewedBy.any((id) => id != myId && id.isNotEmpty) ||
      (widget.message.snapViewedBy.contains(myId) && !widget.isMine);

  Future<void> _tapToView(BuildContext context) async {
    final myId = context.read<AuthProvider>().user?.id ?? '';
    if (_alreadyOpened(myId)) return;

    // For the receiver: open and mark as viewed
    final chat = context.read<ChatProvider>();
    final url = widget.message.mediaUrl;

    if (url == null || url.isEmpty) return;
    final fullUrl = url.startsWith('http') ? url : '${AppConfig.mediaBaseUrl}$url';

    setState(() => _viewing = true);

    // Show full-screen snap
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) => _SnapViewDialog(imageUrl: fullUrl),
    );

    // Mark as viewed after closing
    if (mounted) {
      setState(() => _viewing = false);
      await chat.viewSnap(widget.message.matchId, widget.message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id ?? '';
    final opened = _alreadyOpened(myId);

    if (widget.isMine) {
      return _snapSenderBubble(opened);
    }
    return _snapReceiverBubble(context, opened);
  }

  Widget _snapSenderBubble(bool opened) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            opened ? Icons.photo_outlined : Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            opened ? 'Snap Opened' : 'Snap Sent',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _snapReceiverBubble(BuildContext context, bool opened) {
    return GestureDetector(
      onTap: opened ? null : () => _tapToView(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: opened ? AppTheme.surface2 : const Color(0xFFFF6B6B).withOpacity(0.15),
          border: Border.all(
            color: opened ? AppTheme.surface2 : const Color(0xFFFF6B6B),
            width: 1.5,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_viewing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)),
              )
            else
              Icon(
                opened ? Icons.photo_outlined : Icons.local_fire_department_rounded,
                color: opened ? AppTheme.textLight : const Color(0xFFFF6B6B),
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              opened ? 'Snap Opened' : 'Tap to view',
              style: TextStyle(
                color: opened ? AppTheme.textLight : const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapViewDialog extends StatefulWidget {
  final String imageUrl;
  const _SnapViewDialog({required this.imageUrl});

  @override
  State<_SnapViewDialog> createState() => _SnapViewDialogState();
}

class _SnapViewDialogState extends State<_SnapViewDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-close after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: NetworkImageWidget(imageUrl: widget.imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap to close • Disappears after 10s',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo Bubble ─────────────────────────────────────────────────────────────

class _PhotoBubble extends StatelessWidget {
  final String mediaUrl;
  final bool isMine;
  final VoidCallback onTap;

  const _PhotoBubble({required this.mediaUrl, required this.isMine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 20),
          ),
          border: Border.all(
            color: isMine
                ? AppTheme.primary.withOpacity(0.5)
                : AppTheme.surface2,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 18),
          ),
          child: NetworkImageWidget(
            imageUrl: mediaUrl,
            width: MediaQuery.of(context).size.width * 0.65,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
