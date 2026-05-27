import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../providers/auth_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/match_provider.dart';
import '../providers/premium_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/swipe_card.dart';
import '../widgets/match_modal.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final CardSwiperController _controller = CardSwiperController();
  bool _showMatchModal = false;
  UserModel? _matchedUser;
  String? _matchId;
  bool _deckExhausted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAndLoad();
    });
  }

  Future<void> _initLocationAndLoad() async {
    final api = context.read<ApiService>();
    final discovery = context.read<DiscoveryProvider>();
    await LocationService.updateUserLocation(api);
    if (mounted) discovery.loadUsers();
  }

  // Called when navigating back to this screen (e.g. after changing Settings).
  // Resets and reloads the deck so new preference filters are applied immediately.
  Future<void> _reloadAfterReturn() async {
    final discovery = context.read<DiscoveryProvider>();
    setState(() => _deckExhausted = false);
    await discovery.reset();
    if (mounted) {
      final api = context.read<ApiService>();
      await LocationService.updateUserLocation(api);
      if (mounted) discovery.loadUsers();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isPremium =>
      context.read<PremiumProvider>().isPremium;

  bool get _hasUnlimitedLikes =>
      context.read<PremiumProvider>().isUnlimitedLikes;

  void _onSwipe(int index, int? oldIndex, CardSwiperDirection direction) {
    final provider = context.read<DiscoveryProvider>();
    final users = provider.users;
    // oldIndex is the card that was swiped; index is the new top card
    final swipedIndex = oldIndex ?? index;
    if (swipedIndex >= users.length) return;
    final user = users[swipedIndex];

    if (direction == CardSwiperDirection.right) {
      if (!_hasUnlimitedLikes && !provider.hasLikesLeft) {
        _showLikesExhaustedSnackbar();
        return;
      }
      _handleLike(user);
    } else if (direction == CardSwiperDirection.left) {
      provider.swipeLeft(user.id);
    } else if (direction == CardSwiperDirection.top) {
      _handleSuperLike(user);
    }
  }

  void _showLikesExhaustedSnackbar() {
    AppNotification.primary(
      context,
      'No likes left today. Get Unlimited Likes!',
      icon: Icons.favorite_border,
      actionLabel: 'Upgrade',
      onAction: () => Navigator.pushNamed(context, '/premium'),
    );
  }

  Future<void> _handleLike(UserModel user) async {
    final provider = context.read<DiscoveryProvider>();
    final bypassLimit = _hasUnlimitedLikes;
    if (!bypassLimit && !provider.hasLikesLeft) {
      _showLikesExhaustedSnackbar();
      return;
    }
    final isMatch = await provider.swipeRight(user.id, bypassLimit: bypassLimit);
    if (isMatch && mounted) {
      final matchedUser = provider.matchedUser;
      if (matchedUser != null) {
        // Immediately refresh the Matches tab without a loading spinner
        context.read<MatchProvider>().silentRefresh();
        setState(() {
          _matchedUser = matchedUser;
          _matchId = provider.matchId;
          _showMatchModal = true;
        });
      }
    }
  }

  void _showSuperLikesExhaustedSnackbar() {
    AppNotification.show(
      context,
      message: 'No Super Likes left today. Come back tomorrow!',
      backgroundColor: AppTheme.superLike.withOpacity(0.95),
      textColor: Colors.white,
      icon: Icons.star_rounded,
    );
  }

  Future<void> _handleSuperLike(UserModel user) async {
    final provider = context.read<DiscoveryProvider>();
    if (!provider.hasSuperLikesLeft) {
      _showSuperLikesExhaustedSnackbar();
      return;
    }
    final isMatch = await provider.superLike(user.id);
    if (mounted) {
      final matchedUser = provider.matchedUser;
      if (matchedUser != null) {
        context.read<MatchProvider>().silentRefresh();
        setState(() {
          _matchedUser = matchedUser;
          _matchId = provider.matchId;
          _showMatchModal = true;
        });
      }
    }
  }

  Future<void> _handleRewind() async {
    final provider = context.read<DiscoveryProvider>();
    final isPremium = _isPremium;

    if (!isPremium) {
      // Check if free user already used rewind today
      final usedToday = await provider.hasUsedRewindToday();
      if (usedToday) {
        if (mounted) {
          AppNotification.show(
            context,
            message: 'Upgrade to Gold for unlimited rewinds',
            backgroundColor: const Color(0xFFFFAA00),
            textColor: Colors.white,
            icon: Icons.replay_rounded,
            actionLabel: 'Upgrade',
            onAction: () => Navigator.pushNamed(context, '/premium'),
          );
        }
        return;
      }
    }

    final success = await provider.rewind();
    if (mounted) {
      if (success) {
        _controller.undo();
        if (!isPremium) {
          await provider.markRewindUsed();
        }
        AppNotification.info(context, 'Last swipe undone!');
      } else {
        AppNotification.info(context, 'Nothing to rewind');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
              ).createShader(bounds),
              child: const Text(
                'KneedYou',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            actions: [
              Consumer2<DiscoveryProvider, PremiumProvider>(
                builder: (context, discovery, premium, _) {
                  final unlimited = premium.isUnlimitedLikes;
                  final remaining = discovery.dailyLikesRemaining;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      avatar: Icon(
                        unlimited ? Icons.all_inclusive : Icons.favorite,
                        size: 14,
                        color: (unlimited || remaining > 0) ? AppTheme.primary : Colors.grey,
                      ),
                      label: Text(
                        unlimited ? '∞' : '$remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (unlimited || remaining > 0) ? AppTheme.primary : Colors.grey,
                        ),
                      ),
                      backgroundColor: (unlimited || remaining > 0)
                          ? AppTheme.primary.withOpacity(0.1)
                          : Colors.grey.shade200,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.workspace_premium, color: Color(0xFFFFAA00)),
                tooltip: 'Get Premium',
                onPressed: () => Navigator.pushNamed(context, '/premium'),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () async {
                  await Navigator.pushNamed(context, '/settings');
                  if (mounted) _reloadAfterReturn();
                },
              ),
            ],
          ),
          body: Consumer<DiscoveryProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.users.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.users.isEmpty || _deckExhausted) {
                return _buildEmptyState();
              }

              return Column(
                children: [
                  if (provider.expandedSearch)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppTheme.primary.withOpacity(0.12),
                      child: Row(
                        children: const [
                          Icon(Icons.explore_outlined, size: 16, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No one nearby — showing profiles from further away',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CardSwiper(
                        controller: _controller,
                        cardsCount: provider.users.length,
                        isLoop: false,
                        onSwipe: (index, oldIndex, direction) {
                          _onSwipe(index, oldIndex, direction);
                          // Load more when running low on cards
                          final remaining = provider.users.length - (oldIndex ?? index) - 1;
                          if (remaining < 3 && provider.hasMore) {
                            provider.loadUsers();
                          }
                          return true;
                        },
                        onEnd: () {
                          if (!provider.hasMore) {
                            setState(() => _deckExhausted = true);
                          } else {
                            provider.loadUsers();
                          }
                        },
                        numberOfCardsDisplayed: provider.users.length.clamp(1, 3),
                        backCardOffset: const Offset(0, -15),
                        padding: EdgeInsets.zero,
                        cardBuilder: (context, index, realIndex, isRealIndex) {
                          if (index >= provider.users.length) return const SizedBox();
                          return SwipeCard(
                            user: provider.users[index],
                            isTopCard: index == 0,
                          );
                        },
                      ),
                    ),
                  ),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
        if (_showMatchModal && _matchedUser != null)
          Positioned.fill(
            child: MatchModal(
              currentUser: context.read<AuthProvider>().user!,
              matchedUser: _matchedUser!,
              matchId: _matchId ?? '',
              onKeepSwiping: () {
                setState(() {
                  _showMatchModal = false;
                  _matchId = null;
                });
                context.read<DiscoveryProvider>().clearMatch();
              },
              onSendMessage: () {
                final matchedUser = _matchedUser!;
                final matchId = _matchId;
                setState(() {
                  _showMatchModal = false;
                  _matchId = null;
                });
                context.read<DiscoveryProvider>().clearMatch();
                if (matchId != null && matchId.isNotEmpty) {
                  Navigator.pushNamed(context, '/chat',
                      arguments: {'matchId': matchId, 'user': matchedUser});
                } else {
                  Navigator.pushNamed(context, '/matches');
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Consumer2<DiscoveryProvider, PremiumProvider>(
      builder: (context, discovery, premium, _) {
        final canLike = premium.isUnlimitedLikes || discovery.hasLikesLeft;
        final canSuperLike = discovery.hasSuperLikesLeft;
        final superLikesLeft = discovery.superLikesRemaining;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.close,
              color: AppTheme.error,
              size: 56,
              onPressed: () => _controller.swipeLeft(),
            ),
            _ActionButton(
              icon: Icons.replay_rounded,
              color: const Color(0xFFFFAA00),
              size: 46,
              onPressed: _handleRewind,
            ),
            _SuperLikeButton(
              count: superLikesLeft,
              enabled: canSuperLike,
              onPressed: canSuperLike
                  ? () => _controller.swipeTop()
                  : _showSuperLikesExhaustedSnackbar,
            ),
            _ActionButton(
              icon: Icons.favorite,
              color: canLike ? AppTheme.success : Colors.grey.shade400,
              size: 56,
              onPressed: canLike
                  ? () => _controller.swipeRight()
                  : _showLikesExhaustedSnackbar,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppTheme.textLight),
          const SizedBox(height: 16),
          Text(
            'No more profiles nearby',
            style: TextStyle(fontSize: 18, color: AppTheme.textMedium, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later or expand your distance',
            style: TextStyle(color: AppTheme.textLight),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              setState(() => _deckExhausted = false);
              await context.read<DiscoveryProvider>().reset();
              context.read<DiscoveryProvider>().loadUsers();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(160, 46),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _SuperLikeButton extends StatelessWidget {
  final int count;
  final bool enabled;
  final VoidCallback onPressed;

  const _SuperLikeButton({
    required this.count,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.superLike : Colors.grey.shade400;
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.star_rounded, color: color, size: 23),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: enabled ? AppTheme.superLike : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
