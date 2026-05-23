import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
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
    final hasPhoto = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (hasPhoto)
                _PhotoBubble(
                  mediaUrl: message.mediaUrl!,
                  isMine: isMine,
                  onTap: () => _showFullImage(context, message.mediaUrl!),
                )
              else
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                ),
            ],
          ),
          if (showTime) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  DateFormat.jm().format(message.createdAt.toLocal()),
                  style:
                      const TextStyle(color: AppTheme.textLight, fontSize: 11),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.readBy.length > 1 ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.readBy.length > 1
                        ? AppTheme.accent
                        : AppTheme.textLight,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
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
              child: NetworkImageWidget(
                imageUrl: mediaUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  final String mediaUrl;
  final bool isMine;
  final VoidCallback onTap;

  const _PhotoBubble({
    required this.mediaUrl,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
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
