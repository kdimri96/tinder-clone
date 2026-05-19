import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
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
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ).createShader(bounds),
          child: const Text(
            'Matches',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textMedium),
            onPressed: () => context.read<MatchProvider>().loadMatches(),
          ),
        ],
      ),
      body: Consumer<MatchProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.matches.isEmpty) {
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

          return ListView.builder(
            itemCount: provider.matches.length,
            itemBuilder: (context, index) => _MatchTile(match: provider.matches[index]),
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final MatchModel match;
  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final other = match.otherUser;
    if (other == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
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
        title: Text(
          other.name,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textDark),
        ),
        subtitle: Text(
          match.lastMessage?.text ?? 'Say hello!',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: match.lastMessage != null ? AppTheme.textMedium : AppTheme.textLight,
            fontStyle: match.lastMessage != null ? FontStyle.normal : FontStyle.italic,
            fontSize: 13,
          ),
        ),
        trailing: match.lastMessageAt != null
            ? Text(
                timeago.format(match.lastMessageAt!),
                style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
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
        title: const Text('Unmatch'),
        content: Text('Are you sure you want to unmatch with $name?'),
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
