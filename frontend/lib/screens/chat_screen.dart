import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/network_image_widget.dart';
import '../widgets/report_dialog.dart';
import '../utils/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    // Tell HomeScreen this conversation is active so it suppresses duplicate
    // message notifications for this chat.
    context.read<ChatProvider>().setActiveChat(widget.matchId);

    // Initialise online status from the socket's in-memory map (covers the
    // case where presence:online fired before this screen was opened).
    _isOtherUserOnline = widget.otherUser.isOnline ||
        context.read<SocketService>().isUserOnline(widget.otherUser.id);

    context.read<SocketService>().onPresence(_onPresence);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always reload so real-time messages since last open are fetched.
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

    // Show WhatsApp-style preview & confirmation before sending
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ImagePreviewDialog(file: picked),
    );

    if (confirmed != true || !mounted) return;
    await context.read<ChatProvider>().sendPhoto(widget.matchId, picked);
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leadingWidth: 30,
        title: Row(
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
                      child:
                          const Icon(Icons.person, color: AppTheme.textMedium),
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textMedium),
            color: AppTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'report') {
                showReportBottomSheet(context, widget.otherUser);
              }
            },
            itemBuilder: (context) => [
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
      // resizeToAvoidBottomInset pushes the whole Column up when the keyboard
      // appears so the input bar is always visible above it.
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

                // Scroll to bottom whenever messages change
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

          // Input bar — SafeArea bottom so it clears the Android nav bar
          SafeArea(
            top: false,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surface2)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _sendPhoto,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.image_outlined,
                        color: AppTheme.textMedium, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
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
                ),
              ],
            ),
          ),
          ), // SafeArea
        ],
      ),
    );
  }
}

// ── Image preview dialog (shown before sending) ──────────────────────────────
class _ImagePreviewDialog extends StatefulWidget {
  final XFile file;
  const _ImagePreviewDialog({required this.file});

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined, color: AppTheme.textMedium, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Send photo?',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close, color: AppTheme.textMedium, size: 22),
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
                          child: CircularProgressIndicator(color: Colors.white)),
                    )
                  : Image.memory(
                      _bytes!,
                      fit: BoxFit.contain,
                    ),
            ),

            // Action buttons
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        gradient: AppTheme.primaryGradient,
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
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('Send',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
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

// Three-dot animated typing indicator
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
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
                .clamp(0.3, 1.0);
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
