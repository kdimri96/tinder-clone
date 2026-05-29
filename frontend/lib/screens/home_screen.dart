import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/match_provider.dart';
import '../services/socket_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';
import 'discovery_screen.dart';
import 'matches_screen.dart';
import 'liked_you_screen.dart';
import 'profile_screen.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ID of the last match for which we showed the "you matched!" snackbar.
  // Using ID instead of reference avoids false-positives after API reloads
  // create new MatchModel objects for the same match.
  String? _lastShownMatchId;

  final List<Widget> _screens = const [
    DiscoveryScreen(),
    MatchesScreen(),
    LikedYouScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchProvider>().loadMatches();
      context.read<MatchProvider>().addListener(_onMatchProviderChange);
      context.read<SocketService>().onLikedYou(_onLikedYou);
      context.read<SocketService>().onChatNotification(_onChatNotification);
    });
  }

  @override
  void dispose() {
    context.read<MatchProvider>().removeListener(_onMatchProviderChange);
    context.read<SocketService>().removeLikedYouListener(_onLikedYou);
    context.read<SocketService>().removeChatNotificationListener(_onChatNotification);
    super.dispose();
  }

  void _onMatchProviderChange() {
    if (!mounted) return;
    final provider = context.read<MatchProvider>();
    final newMatch = provider.lastNewMatch;
    if (newMatch != null && newMatch.id != _lastShownMatchId) {
      _lastShownMatchId = newMatch.id;
      final other = newMatch.otherUser;
      final myId = context.read<AuthProvider>().user?.id ?? '';
      if (other != null) {
        final isSuperLikeReceived =
            newMatch.isSuperLike && newMatch.superLikeBy != myId;
        AppNotification.show(
          context,
          message: isSuperLikeReceived
              ? '${other.name} Super Liked you! You can now chat.'
              : 'You matched with ${other.name}!',
          backgroundColor: isSuperLikeReceived
              ? AppTheme.superLike
              : AppTheme.primary,
          textColor: Colors.white,
          icon: isSuperLikeReceived ? Icons.star_rounded : Icons.favorite,
          iconColor: Colors.white,
          actionLabel: 'Chat',
          onAction: () {
            setState(() => _currentIndex = 1);
            Navigator.pushNamed(context, '/chat',
                arguments: {'matchId': newMatch.id, 'user': other});
          },
        );
      }
    }
  }

  void _onLikedYou() {
    if (!mounted) return;
    // Suppress banner if user is already on the Likes tab
    if (_currentIndex == 2) return;
    AppNotification.show(
      context,
      message: 'Someone liked your profile!',
      backgroundColor: AppColors.of(context).surface,
      textColor: AppColors.of(context).textDark,
      icon: Icons.star_rounded,
      iconColor: const Color(0xFFFFAA00),
      actionLabel: 'View',
      onAction: () => _onTabTap(2),
    );
  }

  void _onChatNotification(String matchId, String senderName, String text) {
    if (!mounted) return;
    // Suppress if on Matches tab or already in that specific chat
    if (_currentIndex == 1) return;
    final activeChatId = context.read<ChatProvider>().activeChatMatchId;
    if (activeChatId == matchId) return;

    AppNotification.show(
      context,
      message: '$senderName: $text',
      backgroundColor: AppColors.of(context).surface,
      textColor: AppColors.of(context).textDark,
      icon: Icons.chat_bubble_outline,
      iconColor: AppTheme.primary,
      actionLabel: 'Reply',
      onAction: () => setState(() => _currentIndex = 1),
    );
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      context.read<MatchProvider>().clearNewNotifications();
      // Silently sync in case any events arrived while on another tab
      context.read<MatchProvider>().silentRefresh();
    }
    if (index == 2) context.read<MatchProvider>().clearNewLikes();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchProvider>(
      builder: (context, matchProvider, _) {
        final matchBadge = matchProvider.newNotificationsCount;
        final likesBadge = matchProvider.newLikesCount;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              border:
                  Border(top: BorderSide(color: AppColors.of(context).surface2, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
              backgroundColor: AppColors.of(context).surface,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppColors.of(context).textLight,
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Discover',
                ),
                BottomNavigationBarItem(
                  icon: matchBadge > 0
                      ? Badge(
                          label: Text('$matchBadge'),
                          child: const Icon(Icons.favorite_border),
                        )
                      : const Icon(Icons.favorite_border),
                  activeIcon: matchBadge > 0
                      ? Badge(
                          label: Text('$matchBadge'),
                          child: const Icon(Icons.favorite),
                        )
                      : const Icon(Icons.favorite),
                  label: 'Matches',
                ),
                BottomNavigationBarItem(
                  icon: likesBadge > 0
                      ? Badge(
                          label: Text('$likesBadge'),
                          child: const Icon(Icons.star_border_rounded),
                        )
                      : const Icon(Icons.star_border_rounded),
                  activeIcon: likesBadge > 0
                      ? Badge(
                          label: Text('$likesBadge'),
                          child: const Icon(Icons.star_rounded),
                        )
                      : const Icon(Icons.star_rounded),
                  label: 'Likes',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
