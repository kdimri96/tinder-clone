import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../widgets/network_image_widget.dart';
import '../utils/app_theme.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ).createShader(bounds),
          child: const Text(
            'Matches',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textMedium),
            onPressed: () => context.read<MatchProvider>().loadMatches(),
          ),
        ],
      ),
      body: Consumer2<MatchProvider, AuthProvider>(
        builder: (context, matchProvider, authProvider, _) {
          if (matchProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final myId = authProvider.user?.id ?? '';
          final newMatches = matchProvider.matches
              .where((m) => m.lastMessage == null)
              .toList();
          final conversations = matchProvider.matches
              .where((m) => m.lastMessage != null)
              .toList();

          if (matchProvider.matches.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: matchProvider.loadMatches,
            color: AppTheme.primary,
            child: ListView(
              children: [
                // NEW MATCHES section
                if (newMatches.isNotEmpty) ...[
                  _SectionHeader(title: 'New Matches', count: newMatches.length),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: newMatches.length,
                      itemBuilder: (context, index) =>
                          _NewMatchAvatar(match: newMatches[index]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // MESSAGES section
                if (conversations.isNotEmpty) ...[
                  _SectionHeader(title: 'Messages', count: conversations.length),
                  ...conversations.map((match) =>
                      _ConversationTile(match: match, myId: myId)),
                ],

                // If only new matches and no conversations
                if (conversations.isEmpty && newMatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppTheme.textLight.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Say hello to your matches!',
                          style: TextStyle(color: AppTheme.textMedium, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.2),
                  AppTheme.secondary.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(Icons.favorite_border,
                size: 44, color: AppTheme.primary.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matches yet',
            style: TextStyle(
                fontSize: 18,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start swiping to find your matches!',
            style: TextStyle(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMatchAvatar extends StatelessWidget {
  final MatchModel match;
  const _NewMatchAvatar({required this.match});

  @override
  Widget build(BuildContext context) {
    final other = match.otherUser;
    if (other == null) return const SizedBox();

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: {'matchId': match.id, 'user': other},
      ),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: other.firstPhoto.isNotEmpty
                        ? NetworkImageWidget(
                            imageUrl: other.firstPhoto,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppTheme.surface2,
                            child: const Icon(Icons.person, size: 32, color: AppTheme.textMedium),
                          ),
                  ),
                ),
                if (other.isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              other.name,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final MatchModel match;
  final String myId;
  const _ConversationTile({required this.match, required this.myId});

  @override
  Widget build(BuildContext context) {
    final other = match.otherUser;
    if (other == null) return const SizedBox();

    final isUnread = match.lastMessage != null && !match.lastMessage!.isReadBy(myId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: other.firstPhoto.isNotEmpty
                  ? NetworkImageWidget(
                      imageUrl: other.firstPhoto,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: AppTheme.surface2,
                      child: const Icon(Icons.person, size: 32, color: AppTheme.textMedium),
                    ),
            ),
            if (other.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                other.name,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Text(
          match.lastMessage?.mediaUrl != null
              ? '📷 Photo'
              : (match.lastMessage?.text ?? 'Say hello!'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnread ? AppTheme.textDark : AppTheme.textMedium,
            fontStyle: match.lastMessage != null ? FontStyle.normal : FontStyle.italic,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        trailing: match.lastMessageAt != null
            ? Text(
                timeago.format(match.lastMessageAt!),
                style: TextStyle(
                  color: isUnread ? AppTheme.primary : AppTheme.textLight,
                  fontSize: 11,
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              )
            : null,
        onTap: () => Navigator.pushNamed(
          context,
          '/chat',
          arguments: {'matchId': match.id, 'user': other},
        ),
        onLongPress: () => _showUnmatchDialog(context, match.id, other.name),
      ),
    );
  }

  void _showUnmatchDialog(BuildContext context, String matchId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unmatch', style: TextStyle(color: AppTheme.textDark)),
        content: Text('Are you sure you want to unmatch with $name?',
            style: const TextStyle(color: AppTheme.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMedium)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MatchProvider>().unmatch(matchId);
            },
            child: const Text('Unmatch', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
