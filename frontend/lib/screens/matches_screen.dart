import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../models/match_model.dart';
import '../widgets/network_image_widget.dart';
import '../utils/app_theme.dart';
import '../utils/app_colors.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).background,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ).createShader(bounds),
          child: Text(
            'Matches',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.of(context).textMedium),
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
          // Super-like matches (no messages yet) sorted first
          final newMatches = [
            ...matchProvider.matches.where((m) => m.lastMessage == null && m.isSuperLike),
            ...matchProvider.matches.where((m) => m.lastMessage == null && !m.isSuperLike),
          ];
          final conversations = matchProvider.matches
              .where((m) => m.lastMessage != null)
              .toList();

          if (matchProvider.matches.isEmpty) {
            return _buildEmptyState(context);
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
                            size: 48, color: AppColors.of(context).textLight.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Say hello to your matches!',
                          style: TextStyle(color: AppColors.of(context).textMedium, fontSize: 14),
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

  Widget _buildEmptyState(BuildContext context) {
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
          Text(
            'No matches yet',
            style: TextStyle(
                fontSize: 18,
                color: AppColors.of(context).textDark,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Start swiping to find your matches!',
            style: TextStyle(color: AppColors.of(context).textMedium),
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
            style: TextStyle(
              color: AppColors.of(context).textDark,
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
    final isSuperLike = match.isSuperLike;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: {'matchId': match.id, 'user': other},
      ),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSuperLike
                        ? LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                          )
                        : AppTheme.primaryGradient,
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
                            color: AppColors.of(context).surface2,
                            child: Icon(Icons.person, size: 32, color: AppColors.of(context).textMedium),
                          ),
                  ),
                ),
                if (isSuperLike)
                  Positioned(
                    bottom: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.superLike,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              'Super',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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
                        border: Border.all(color: AppColors.of(context).background, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              other.name,
              style: TextStyle(
                color: isSuperLike ? AppTheme.superLike : AppColors.of(context).textDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
        color: AppColors.of(context).surface,
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
                      color: AppColors.of(context).surface2,
                      child: Icon(Icons.person, size: 32, color: AppColors.of(context).textMedium),
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
                    border: Border.all(color: AppColors.of(context).surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            if (match.isSuperLike)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.star_rounded, color: AppTheme.superLike, size: 14),
              ),
            Expanded(
              child: Text(
                other.name,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                  color: match.isSuperLike ? AppTheme.superLike : AppColors.of(context).textDark,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
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
            color: isUnread ? AppColors.of(context).textDark : AppColors.of(context).textMedium,
            fontStyle: match.lastMessage != null ? FontStyle.normal : FontStyle.italic,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        trailing: match.lastMessageAt != null
            ? Text(
                timeago.format(match.lastMessageAt!),
                style: TextStyle(
                  color: isUnread ? AppTheme.primary : AppColors.of(context).textLight,
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
        backgroundColor: AppColors.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unmatch', style: TextStyle(color: AppColors.of(context).textDark)),
        content: Text('Are you sure you want to unmatch with $name?',
            style: TextStyle(color: AppColors.of(context).textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.of(context).textMedium)),
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
