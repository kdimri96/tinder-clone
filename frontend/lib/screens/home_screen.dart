import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      context.read<SocketService>().onLikedYou(_onLikedYou);
    });
  }

  @override
  void dispose() {
    context.read<SocketService>().removeLikedYouListener(_onLikedYou);
    super.dispose();
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

  void _onTabTap(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 2) _newLikesCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surface2, width: 0.5)),
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
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
  }
}
