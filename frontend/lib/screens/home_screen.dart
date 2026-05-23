import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/match_provider.dart';
import '../services/socket_service.dart';
import '../utils/app_theme.dart';
import 'discovery_screen.dart';
import 'matches_screen.dart';
import 'liked_you_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _newLikesCount = 0;

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
      if (other != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You matched with ${other.name}!',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Chat',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _currentIndex = 1);
                Navigator.pushNamed(context, '/chat',
                    arguments: {'matchId': newMatch.id, 'user': other});
              },
            ),
          ),
        );
      }
    }
  }

  void _onLikedYou() {
    if (!mounted) return;
    setState(() => _newLikesCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Someone liked your profile!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'See who',
          textColor: Colors.white,
          onPressed: () => setState(() {
            _currentIndex = 2;
            _newLikesCount = 0;
          }),
        ),
      ),
    );
  }

  void _onChatNotification(String matchId, String senderName, String text) {
    if (!mounted) return;
    // Suppress if on Matches tab or already in that specific chat
    if (_currentIndex == 1) return;
    final activeChatId = context.read<ChatProvider>().activeChatMatchId;
    if (activeChatId == matchId) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  Text(
                    text,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.surface2),
        ),
        action: SnackBarAction(
          label: 'Reply',
          textColor: AppTheme.primary,
          onPressed: () {
            setState(() => _currentIndex = 1);
          },
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) context.read<MatchProvider>().clearNewNotifications();
      if (index == 2) _newLikesCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchProvider>(
      builder: (context, matchProvider, _) {
        final matchBadge = matchProvider.newNotificationsCount;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border(top: BorderSide(color: AppTheme.surface2, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
              backgroundColor: AppTheme.surface,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.textLight,
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
                  icon: _newLikesCount > 0
                      ? Badge(
                          label: Text('$_newLikesCount'),
                          child: const Icon(Icons.star_border_rounded),
                        )
                      : const Icon(Icons.star_border_rounded),
                  activeIcon: _newLikesCount > 0
                      ? Badge(
                          label: Text('$_newLikesCount'),
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
