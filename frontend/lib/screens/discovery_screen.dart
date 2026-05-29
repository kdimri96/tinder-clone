import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discovery_provider.dart';
import '../providers/match_provider.dart';
import '../providers/premium_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/hinge_profile_card.dart';
import '../widgets/like_comment_sheet.dart';
import '../widgets/match_modal.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';
import '../utils/app_colors.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  int _profileIndex = 0;
  bool _showMatchModal = false;
  UserModel? _matchedUser;
  String? _matchId;

  // Feedback overlay (like / pass flash)
  late AnimationController _feedbackCtrl;
  late Animation<double> _feedbackOpacity;
  bool _feedbackIsLike = true;

  @override
  void initState() {
    super.initState();

    _feedbackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _feedbackOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAndLoad();
    });
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndLoad() async {
    final api = context.read<ApiService>();
    final discovery = context.read<DiscoveryProvider>();
    await LocationService.updateUserLocation(api);
    if (mounted) discovery.loadUsers();
  }

  Future<void> _reloadAfterReturn() async {
    final discovery = context.read<DiscoveryProvider>();
    setState(() => _profileIndex = 0);
    await discovery.reset();
    if (mounted) {
      final api = context.read<ApiService>();
      await LocationService.updateUserLocation(api);
      if (mounted) discovery.loadUsers();
    }
  }

  bool get _isPremium => context.read<PremiumProvider>().isPremium;
  bool get _hasUnlimitedLikes => context.read<PremiumProvider>().isUnlimitedLikes;

  UserModel? _currentUser(DiscoveryProvider provider) {
    if (_profileIndex >= provider.users.length) return null;
    return provider.users[_profileIndex];
  }

  void _showFeedback({required bool isLike}) {
    setState(() => _feedbackIsLike = isLike);
    _feedbackCtrl.forward(from: 0).then((_) {
      _feedbackCtrl.reverse();
    });
  }

  void _preloadNextIfNeeded(DiscoveryProvider provider) {
    final remaining = provider.users.length - _profileIndex - 1;
    if (remaining < 3 && provider.hasMore) {
      provider.loadUsers();
    }
  }

  // Quick like from swipe gesture — no comment sheet
  Future<void> _handleLike() async {
    await _doLike(comment: null);
  }

  // Like from a ❤️ button tap — shows comment sheet
  Future<void> _handleSectionLike(UserModel user, String sectionLabel) async {
    final provider = context.read<DiscoveryProvider>();

    final canLike = _hasUnlimitedLikes || provider.hasLikesLeft;
    if (!canLike) {
      _showLikesExhaustedSnackbar();
      return;
    }

    final result = await LikeCommentSheet.show(
      context,
      userName: user.name,
      sectionLabel: sectionLabel,
    );
    if (result == null) return; // dismissed

    await _doLike(comment: result.isEmpty ? null : result);
  }

  Future<void> _doLike({String? comment}) async {
    final provider = context.read<DiscoveryProvider>();
    final user = _currentUser(provider);
    if (user == null) return;

    final canLike = _hasUnlimitedLikes || provider.hasLikesLeft;
    if (!canLike) {
      _showLikesExhaustedSnackbar();
      return;
    }

    _showFeedback(isLike: true);
    _preloadNextIfNeeded(provider);
    setState(() => _profileIndex++);

    final isMatch = await provider.swipeRight(
      user.id,
      bypassLimit: _hasUnlimitedLikes,
      comment: comment,
    );

    if (isMatch && mounted) {
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

  Future<void> _handlePass() async {
    final provider = context.read<DiscoveryProvider>();
    final user = _currentUser(provider);
    if (user == null) return;

    _showFeedback(isLike: false);
    _preloadNextIfNeeded(provider);
    setState(() => _profileIndex++);
    provider.swipeLeft(user.id);
  }

  Future<void> _handleSuperLike() async {
    final provider = context.read<DiscoveryProvider>();
    final user = _currentUser(provider);
    if (user == null) return;

    if (!provider.hasSuperLikesLeft) {
      _showSuperLikesExhaustedSnackbar();
      return;
    }

    _showFeedback(isLike: true);
    _preloadNextIfNeeded(provider);
    setState(() => _profileIndex++);

    final isMatch = await provider.superLike(user.id);
    if (mounted && isMatch) {
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
    if (_profileIndex == 0) {
      AppNotification.info(context, 'Nothing to rewind');
      return;
    }

    final provider = context.read<DiscoveryProvider>();
    final isPremium = _isPremium;

    if (!isPremium) {
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
    if (mounted && success) {
      setState(() => _profileIndex--);
      if (!isPremium) await provider.markRewindUsed();
      AppNotification.info(context, 'Last swipe undone!');
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

  void _showSuperLikesExhaustedSnackbar() {
    AppNotification.show(
      context,
      message: 'No Super Likes left today. Come back tomorrow!',
      backgroundColor: AppTheme.superLike.withOpacity(0.95),
      textColor: Colors.white,
      icon: Icons.star_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.of(context).background,
          appBar: _buildAppBar(),
          body: Consumer<DiscoveryProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.users.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final user = _currentUser(provider);

              if (user == null) {
                return _buildEmptyState(provider);
              }

              return Stack(
                children: [
                  // Expanded search banner
                  if (provider.expandedSearch)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _ExpandedSearchBanner(),
                    ),

                  // Profile content with animated transition
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: HingeProfileCard(
                      key: ValueKey('${user.id}_$_profileIndex'),
                      user: user,
                      onLike: _handleLike,
                      onSectionLike: (label) => _handleSectionLike(user, label),
                      onPass: _handlePass,
                    ),
                  ),

                  // Like / Pass feedback flash overlay
                  AnimatedBuilder(
                    animation: _feedbackOpacity,
                    builder: (_, __) => IgnorePointer(
                      child: Container(
                        color: (_feedbackIsLike ? AppTheme.success : AppTheme.error)
                            .withOpacity(_feedbackOpacity.value * 0.15),
                      ),
                    ),
                  ),

                  // Floating action bar at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildActionBar(provider),
                  ),
                ],
              );
            },
          ),
        ),

        // Match modal
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.of(context).background,
      elevation: 0,
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
                  color: (unlimited || remaining > 0)
                      ? AppTheme.primary
                      : Colors.grey,
                ),
                label: Text(
                  unlimited ? '∞' : '$remaining',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: (unlimited || remaining > 0)
                        ? AppTheme.primary
                        : Colors.grey,
                  ),
                ),
                backgroundColor: (unlimited || remaining > 0)
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.grey.shade800,
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
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                themeProvider.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(themeProvider.isDark),
                color: themeProvider.isDark ? const Color(0xFFFFDD57) : AppColors.of(context).textDark,
              ),
            ),
            tooltip: themeProvider.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () => themeProvider.toggle(),
          ),
        ),
        IconButton(
          icon: Icon(Icons.tune),
          onPressed: () async {
            await Navigator.pushNamed(context, '/settings');
            if (mounted) _reloadAfterReturn();
          },
        ),
      ],
    );
  }

  Widget _buildActionBar(DiscoveryProvider provider) {
    return Consumer<PremiumProvider>(
      builder: (context, premium, _) {
        final canLike = premium.isUnlimitedLikes || provider.hasLikesLeft;
        final canSuperLike = provider.hasSuperLikesLeft;
        final user = _currentUser(provider);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.of(context).background.withOpacity(0),
                AppColors.of(context).background.withOpacity(0.92),
                AppColors.of(context).background,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
              28, 20, 28, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rewind
              _ActionBtn(
                icon: Icons.replay_rounded,
                color: const Color(0xFFFFAA00),
                size: 50,
                onTap: _handleRewind,
              ),

              // Pass
              _ActionBtn(
                icon: Icons.close_rounded,
                color: AppTheme.error,
                size: 62,
                onTap: _handlePass,
                label: 'Pass',
              ),

              // Super Like
              _SuperLikeBtn(
                count: provider.superLikesRemaining,
                enabled: canSuperLike,
                onTap: canSuperLike
                    ? _handleSuperLike
                    : _showSuperLikesExhaustedSnackbar,
              ),

              // Like — shows comment sheet
              _ActionBtn(
                icon: Icons.favorite_rounded,
                color: canLike ? AppTheme.success : Colors.grey.shade600,
                size: 62,
                gradient: canLike
                    ? const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                onTap: (canLike && user != null)
                    ? () => _handleSectionLike(user, 'Profile')
                    : _showLikesExhaustedSnackbar,
                label: 'Like',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(DiscoveryProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.of(context).surface,
              border: Border.all(color: AppColors.of(context).surface2),
            ),
            child: Icon(Icons.explore_outlined,
                size: 44, color: AppColors.of(context).textLight),
          ),
          const SizedBox(height: 20),
          Text(
            'You\'ve seen everyone nearby',
            style: TextStyle(
                fontSize: 18,
                color: AppColors.of(context).textDark,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Expand your distance or check back later',
            style: TextStyle(color: AppColors.of(context).textMedium, fontSize: 14),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () async {
              setState(() => _profileIndex = 0);
              await provider.reset();
              if (mounted) provider.loadUsers();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expanded search banner ────────────────────────────────────────────────────

class _ExpandedSearchBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primary.withOpacity(0.12),
      child: const Row(
        children: [
          Icon(Icons.explore_outlined, size: 15, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No one nearby — showing profiles from further away',
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String? label;
  final Gradient? gradient;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.label,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradient == null ? AppColors.of(context).surface : null,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon,
                color: gradient != null ? Colors.white : color,
                size: size * 0.48),
          ),
          if (label != null) ...[
            const SizedBox(height: 5),
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Super Like button with badge ──────────────────────────────────────────────

class _SuperLikeBtn extends StatelessWidget {
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  const _SuperLikeBtn({
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.superLike : Colors.grey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.of(context).surface,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.star_rounded, color: color, size: 25),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
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
          const SizedBox(height: 5),
          Text(
            'Star',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
