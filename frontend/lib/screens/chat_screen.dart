import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/network_image_widget.dart';
import '../widgets/report_dialog.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final UserModel otherUser;

  const ChatScreen({
    Key? key,
    required this.matchId,
    required this.otherUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isOtherUserOnline = false;
  bool _hasText = false;

  // Audio recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final List<int> _audioBytes = [];
  StreamSubscription<Uint8List>? _audioSub;

  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().setActiveChat(widget.matchId);

    _isOtherUserOnline = widget.otherUser.isOnline ||
        context.read<SocketService>().isUserOnline(widget.otherUser.id);

    context.read<SocketService>().onPresence(_onPresence);

    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.matchId);
    });
  }

  @override
  void dispose() {
    context.read<ChatProvider>().setActiveChat(null);
    context.read<SocketService>().removePresenceListener(_onPresence);
    _textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _audioSub?.cancel();
    _recorder.dispose();
    context.read<ChatProvider>().stopTyping(widget.matchId);
    super.dispose();
  }

  void _onPresence(String userId, bool isOnline) {
    if (!mounted || userId != widget.otherUser.id) return;
    setState(() => _isOtherUserOnline = isOnline);
  }

  void _onTypingChanged(String text) {
    final chat = context.read<ChatProvider>();
    if (!_isTyping) {
      _isTyping = true;
      chat.startTyping(widget.matchId);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      chat.stopTyping(widget.matchId);
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _isTyping = false;
    _typingTimer?.cancel();
    context.read<ChatProvider>().stopTyping(widget.matchId);
    await context.read<ChatProvider>().sendMessage(widget.matchId, text);
    _scrollToBottom();
  }

  Future<void> _sendPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MediaPreviewDialog(
        file: picked,
        title: 'Send photo?',
        sendLabel: 'Send Photo',
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<ChatProvider>().sendPhoto(widget.matchId, picked);
    if (mounted) {
      final err = context.read<ChatProvider>().error;
      if (err != null) {
        AppNotification.error(context, 'Failed to send photo: $err');
      } else {
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendSnap() async {
    // Show camera choice (photo vs video), except on web where only photo works
    String choice = 'photo';
    if (!kIsWeb) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const _CameraChoiceSheet(),
      );
      if (picked == null || !mounted) return;
      choice = picked;
    }

    final picker = ImagePicker();
    XFile? file;

    if (choice == 'photo') {
      file = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 85);
    } else {
      file = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 30));
    }

    if (file == null || !mounted) return;
    await _confirmAndSendSnap(file, isVideo: choice == 'video');
  }

  Future<void> _confirmAndSendSnap(XFile file, {required bool isVideo}) async {
    bool confirmed = false;

    if (!isVideo) {
      confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (_) => _MediaPreviewDialog(
              file: file,
              title: 'Send as Snap?',
              subtitle: 'Recipient can only view this once',
              sendLabel: 'Send Snap',
              isSnap: true,
            ),
          ) ??
          false;
    } else {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.videocam_outlined, color: Colors.deepOrange),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Send video snap?',
                      style: TextStyle(
                          color: AppTheme.textDark, fontSize: 16)),
                ),
              ]),
              content: const Text(
                'Recipient can watch this video only once.',
                style:
                    TextStyle(color: AppTheme.textMedium, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textMedium)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed || !mounted) return;

    await context.read<ChatProvider>().sendSnap(widget.matchId, file);
    if (mounted) {
      final err = context.read<ChatProvider>().error;
      if (err != null) {
        AppNotification.error(context, 'Failed to send snap: $err');
      } else {
        _scrollToBottom();
      }
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) {
      AppNotification.error(context, 'Microphone permission denied');
      return;
    }

    _audioBytes.clear();
    _recordingSeconds = 0;

    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    final stream = await _recorder.startStream(
      RecordConfig(encoder: encoder, sampleRate: 44100, bitRate: 128000),
    );
    _audioSub = stream.listen((data) => _audioBytes.addAll(data));

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 60) _stopAndSendRecording();
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    await _recorder.stop();
    await _audioSub?.cancel();
    _audioSub = null;

    final duration = _recordingSeconds;
    setState(() => _isRecording = false);

    if (_audioBytes.isEmpty || !mounted) return;

    final bytes = Uint8List.fromList(_audioBytes);
    final filename = kIsWeb ? 'voice.webm' : 'voice.aac';

    await context
        .read<ChatProvider>()
        .sendAudio(widget.matchId, bytes, duration, filename);

    if (mounted) {
      final err = context.read<ChatProvider>().error;
      if (err != null) {
        AppNotification.error(context, 'Failed to send voice message: $err');
      } else {
        _scrollToBottom();
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder.cancel();
    await _audioSub?.cancel();
    _audioSub = null;
    _audioBytes.clear();
    setState(() => _isRecording = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leadingWidth: 30,
        title: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/user-profile',
              arguments: widget.otherUser),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.otherUser.firstPhoto.isNotEmpty
                    ? NetworkImageWidget(
                        imageUrl: widget.otherUser.firstPhoto,
                        width: 40,
                        height: 40,
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: AppTheme.surface2,
                        child: const Icon(Icons.person,
                            color: AppTheme.textMedium),
                      ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUser.name,
                      style: const TextStyle(
                          fontSize: 16, color: AppTheme.textDark)),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOtherUserOnline
                              ? AppTheme.success
                              : AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOtherUserOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOtherUserOnline
                              ? AppTheme.success
                              : AppTheme.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textMedium),
            color: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'view_profile') {
                Navigator.pushNamed(context, '/user-profile',
                    arguments: widget.otherUser);
              } else if (value == 'report') {
                showReportBottomSheet(context, widget.otherUser);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'view_profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: AppTheme.primary, size: 18),
                    SizedBox(width: 10),
                    Text('View Profile',
                        style: TextStyle(color: AppTheme.textDark)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: AppTheme.error, size: 18),
                    SizedBox(width: 10),
                    Text('Report / Block',
                        style: TextStyle(color: AppTheme.textDark)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // Message list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, _) {
                if (chat.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = chat.getMessages(widget.matchId);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                          ),
                          child: const Icon(Icons.favorite,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "You matched with ${widget.otherUser.name}!",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Say hello to start the conversation',
                          style: TextStyle(color: AppTheme.textMedium),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine =
                        msg.senderId == myId || msg.senderId == 'me';
                    final showTime = index == messages.length - 1 ||
                        messages[index + 1]
                                .createdAt
                                .difference(msg.createdAt)
                                .inMinutes >
                            5;
                    return MessageBubble(
                        message: msg, isMine: isMine, showTime: showTime);
                  },
                );
              },
            ),
          ),

          // Typing indicator
          Consumer<ChatProvider>(
            builder: (context, chat, _) {
              if (!chat.isTyping(widget.matchId)) return const SizedBox();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _TypingDots(),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.otherUser.name} is typing',
                      style: const TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              );
            },
          ),

          // Recording bar (shown instead of input bar when recording)
          if (_isRecording)
            SafeArea(
              top: false,
              child: _RecordingBar(
                seconds: _recordingSeconds,
                formatDuration: _formatDuration,
                onCancel: _cancelRecording,
                onSend: _stopAndSendRecording,
              ),
            )
          else
            // Normal input bar
            SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.surface2)),
                ),
                child: Row(
                  children: [
                    // Gallery photo button
                    _InputIconButton(
                      icon: Icons.image_outlined,
                      onTap: _sendPhoto,
                    ),
                    const SizedBox(width: 6),
                    // Snap button
                    _InputIconButton(
                      icon: Icons.camera_alt_outlined,
                      onTap: _sendSnap,
                    ),
                    const SizedBox(width: 8),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onChanged: _onTypingChanged,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(
                            color: AppTheme.textDark, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle:
                              const TextStyle(color: AppTheme.textLight),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          filled: true,
                          fillColor: AppTheme.surface2,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button (text) or Mic button (no text)
                    if (_hasText)
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _startRecording,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Recording bar ─────────────────────────────────────────────────────────────
class _RecordingBar extends StatelessWidget {
  final int seconds;
  final String Function(int) formatDuration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingBar({
    required this.seconds,
    required this.formatDuration,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surface2)),
      ),
      child: Row(
        children: [
          // Cancel
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.error.withOpacity(0.1),
              ),
              child: const Icon(Icons.delete_outline,
                  color: AppTheme.error, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Pulsing dot + timer
          _RecordingPulse(),
          const SizedBox(width: 8),
          Text(
            formatDuration(seconds),
            style: const TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          // Animated waveform
          const Expanded(child: _RecordingWaveform()),
          const SizedBox(width: 12),
          // Send
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing red recording indicator ──────────────────────────────────────────
class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse();

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.error.withOpacity(_anim.value),
        ),
      ),
    );
  }
}

// ── Animated waveform bars for recording ─────────────────────────────────────
class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform();

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const int _bars = 20;
  static const List<double> _heights = [
    0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6, 0.3, 0.7, 0.5,
    0.9, 0.4, 0.8, 0.6, 0.3, 0.7, 0.5, 0.9, 0.4, 0.8,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_bars, (i) {
            final phase = (_ctrl.value + i * 0.07) % 1.0;
            final h = _heights[i] * (0.4 + phase * 0.6);
            return Container(
              width: 2.5,
              height: 20 * h,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Small icon button for input bar ──────────────────────────────────────────
class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _InputIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppTheme.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.textMedium, size: 20),
      ),
    );
  }
}

// ── Media preview dialog (photo or snap) ─────────────────────────────────────
class _MediaPreviewDialog extends StatefulWidget {
  final XFile file;
  final String title;
  final String? subtitle;
  final String sendLabel;
  final bool isSnap;

  const _MediaPreviewDialog({
    required this.file,
    required this.title,
    this.subtitle,
    required this.sendLabel,
    this.isSnap = false,
  });

  @override
  State<_MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<_MediaPreviewDialog> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    widget.file.readAsBytes().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              color: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    widget.isSnap
                        ? Icons.camera_alt_outlined
                        : Icons.image_outlined,
                    color: widget.isSnap ? Colors.deepOrange : AppTheme.textMedium,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                                color: AppTheme.textLight, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close,
                        color: AppTheme.textMedium, size: 22),
                  ),
                ],
              ),
            ),

            // Image preview
            Container(
              color: Colors.black,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              width: double.infinity,
              child: _bytes == null
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                    )
                  : Image.memory(_bytes!, fit: BoxFit.contain),
            ),

            // Action buttons
            Container(
              color: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMedium,
                        side: const BorderSide(color: AppTheme.surface2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: widget.isSnap
                            ? const LinearGradient(colors: [
                                Colors.deepOrange,
                                Colors.orange
                              ])
                            : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(
                          widget.isSnap
                              ? Icons.camera_alt_rounded
                              : Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          widget.sendLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera choice bottom sheet ────────────────────────────────────────────────
class _CameraChoiceSheet extends StatelessWidget {
  const _CameraChoiceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera Snap',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recipient can only view once',
            style: TextStyle(color: AppTheme.textLight, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  color: Colors.deepOrange, size: 20),
            ),
            title: const Text('Take Photo',
                style: TextStyle(
                    color: AppTheme.textDark, fontWeight: FontWeight.w600)),
            subtitle: const Text('One-time view photo',
                style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_outlined,
                  color: Colors.deepOrange, size: 20),
            ),
            title: const Text('Record Video',
                style: TextStyle(
                    color: AppTheme.textDark, fontWeight: FontWeight.w600)),
            subtitle: const Text('One-time view video (max 30s)',
                style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Three-dot animated typing indicator ──────────────────────────────────────
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_anim.value - i * 0.2).clamp(0.0, 1.0);
            final opacity =
                (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.textLight.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
