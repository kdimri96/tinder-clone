import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import '../widgets/match_modal.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';

class LikedYouScreen extends StatefulWidget {
  const LikedYouScreen({Key? key}) : super(key: key);

  @override
  State<LikedYouScreen> createState() => _LikedYouScreenState();
}

class _LikedYouScreenState extends State<LikedYouScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _error;
  bool _showMatchModal = false;
  UserModel? _matchedUser;

  @override
  void initState() {
    super.initState();
    _loadLikedYou();
  }

  Future<void> _loadLikedYou() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final users = await api.getLikedYou();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleTapUser(UserModel user) async {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (!isPremium) return;

    try {
      final api = context.read<ApiService>();
      final result = await api.swipe(targetId: user.id, direction: 'like');
      if (mounted) {
        setState(() {
          _users.removeWhere((u) => u.id == user.id);
        });
        if (result['match'] != null) {
          final matchData = result['match']['users'] as List;
          final matchedUser = UserModel.fromJson(
            matchData.firstWhere(
              (u) => u['_id'] == user.id,
              orElse: () => matchData[0],
            ),
          );
          setState(() {
            _matchedUser = matchedUser;
            _showMatchModal = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotification.error(context, 'Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            title: ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'Liked You',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: AppTheme.textDark),
          ),
          body: _buildBody(),
        ),
        if (_showMatchModal && _matchedUser != null)
          Positioned.fill(
            child: MatchModal(
              currentUser: context.read<AuthProvider>().user!,
              matchedUser: _matchedUser!,
              matchId: '',
              onKeepSwiping: () => setState(() => _showMatchModal = false),
              onSendMessage: () {
                setState(() => _showMatchModal = false);
                Navigator.pushNamed(context, '/matches');
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load',
              style: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadLikedYou,
              child: const Text('Try again', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
    }

    return Consumer<PremiumProvider>(
      builder: (context, premium, _) {
        final isPremium = premium.isPremium;

        if (!isPremium) {
          return _buildLockedView();
        }

        if (_users.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _loadLikedYou,
          color: AppTheme.primary,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return _LikedUserCard(
                user: user,
                onTap: () => _handleTapUser(user),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLockedView() {
    final count = _users.length;
    return Stack(
      children: [
        // Blurred grid in background
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.3 + (index % 3) * 0.1),
                        AppTheme.secondary.withOpacity(0.3 + (index % 2) * 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.person, size: 60, color: Colors.white30),
                ),
              ),
            );
          },
        ),
        // Overlay card
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.surface2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  count > 0 ? '$count ${count == 1 ? 'person' : 'people'} liked you!' : 'See Who Liked You',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  count > 0
                      ? 'Upgrade to Gold to see who liked your profile and match with them.'
                      : 'Upgrade to Gold to see all the people who already liked your profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMedium,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium, color: Color(0xFFFFAA00), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade to Gold',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: const Icon(Icons.favorite_border, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No likes yet',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep swiping to get more visibility!',
            style: TextStyle(color: AppTheme.textMedium, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _LikedUserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _LikedUserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              user.photos.isNotEmpty
                  ? NetworkImageWidget(
                      imageUrl: user.photos.first,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppTheme.surface2,
                      child: const Icon(Icons.person, size: 60, color: AppTheme.textLight),
                    ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Like badge at top
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 16),
                ),
              ),

              // User info at bottom
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.age != null ? '${user.name}, ${user.age}' : user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.job != null && user.job!.isNotEmpty)
                      Text(
                        user.job!,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Tap to match overlay hint
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0),
                        AppTheme.primary.withOpacity(0.15),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
