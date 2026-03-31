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
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                  Icon(Icons.favorite_border, size: 80, color: AppTheme.textLight),
                  const SizedBox(height: 16),
                  Text(
                    'No matches yet',
                    style: TextStyle(fontSize: 18, color: AppTheme.textMedium, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start swiping to find your matches!',
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.matches.length,
            itemBuilder: (context, index) {
              return _MatchTile(match: provider.matches[index]);
            },
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: other.firstPhoto.isNotEmpty
                ? NetworkImageWidget(
                    imageUrl: other.firstPhoto,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.person, size: 36, color: Colors.grey),
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
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        other.name,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text(
        match.lastMessage?.text ?? 'Say hello! 👋',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: match.lastMessage != null ? AppTheme.textMedium : AppTheme.textLight,
          fontStyle: match.lastMessage != null ? FontStyle.normal : FontStyle.italic,
        ),
      ),
      trailing: match.lastMessageAt != null
          ? Text(
              timeago.format(match.lastMessageAt!),
              style: TextStyle(color: AppTheme.textLight, fontSize: 12),
            )
          : null,
      onTap: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: {'matchId': match.id, 'user': other},
      ),
      onLongPress: () => _showUnmatchDialog(context, match.id, other.name),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MatchProvider>().unmatch(matchId);
            },
            child: Text('Unmatch', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
