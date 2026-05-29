import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_config.dart';
import '../utils/app_theme.dart';
import '../widgets/network_image_widget.dart';
import '../utils/app_colors.dart';

class HingeProfileCard extends StatelessWidget {
  final UserModel user;

  /// Called by the swipe gesture — quick like, no section context.
  final VoidCallback onLike;

  /// Called by ❤️ buttons with the section label (e.g. 'About me', 'Photo 2').
  final void Function(String sectionLabel) onSectionLike;

  final VoidCallback onPass;

  const HingeProfileCard({
    Key? key,
    required this.user,
    required this.onLike,
    required this.onSectionLike,
    required this.onPass,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photos = user.photos;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero photo ──────────────────────────────────────────────
          _HeroSection(
            user: user,
            onLike: onLike,
            onSectionLike: () => onSectionLike('Profile photo'),
            onPass: onPass,
          ),

          const SizedBox(height: 12),

          // ── Info chips ──────────────────────────────────────────────
          _InfoSection(user: user),

          // ── Bio prompt ──────────────────────────────────────────────
          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PromptSection(
              text: user.bio,
              onLike: () => onSectionLike('About me'),
            ),
          ],

          // ── Second photo ────────────────────────────────────────────
          if (photos.length > 1) ...[
            const SizedBox(height: 12),
            _PhotoSection(
              photoUrl: photos[1],
              label: 'Photo 2',
              onLike: () => onSectionLike('Photo 2'),
            ),
          ],

          // ── Interests ───────────────────────────────────────────────
          if (user.interests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InterestsSection(
              interests: user.interests,
              onLike: () => onSectionLike('Interests'),
            ),
          ],

          // ── Remaining photos ────────────────────────────────────────
          for (int i = 2; i < photos.length; i++) ...[
            const SizedBox(height: 12),
            _PhotoSection(
              photoUrl: photos[i],
              label: 'Photo ${i + 1}',
              onLike: () => onSectionLike('Photo ${i + 1}'),
            ),
          ],

          // Space for the floating action bar
          const SizedBox(height: 130),
        ],
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLike;
  final VoidCallback onSectionLike;
  final VoidCallback onPass;

  const _HeroSection({
    required this.user,
    required this.onLike,
    required this.onSectionLike,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    final photo = user.firstPhoto;
    final fullUrl = photo.startsWith('http')
        ? photo
        : photo.isNotEmpty
            ? '${AppConfig.mediaBaseUrl}$photo'
            : '';

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) onLike();
        if ((d.primaryVelocity ?? 0) < -300) onPass();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.of(context).surface,
        ),
        clipBehavior: Clip.hardEdge,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              fullUrl.isNotEmpty
                  ? NetworkImageWidget(imageUrl: fullUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.of(context).surface2,
                      child: Icon(Icons.person, size: 80, color: AppColors.of(context).textLight),
                    ),

              // Bottom gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.78),
                      ],
                    ),
                  ),
                ),
              ),

              // Name / age / online
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (user.age != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${user.age}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (user.isOnline) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Active now',
                                  style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    _SectionLikeButton(onTap: onSectionLike),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info section ─────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final UserModel user;
  const _InfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (user.job != null && user.job!.isNotEmpty) {
      items.add(_InfoChip(icon: Icons.work_outline_rounded, label: user.job!));
    }
    if (user.school != null && user.school!.isNotEmpty) {
      items.add(_InfoChip(icon: Icons.school_outlined, label: user.school!));
    }
    if (user.distance != null) {
      final dist = user.distance! < 1
          ? '< 1 km away'
          : '${user.distance!.toStringAsFixed(0)} km away';
      items.add(_InfoChip(icon: Icons.place_outlined, label: dist));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).surface2.withOpacity(0.4)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.of(context).textMedium,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Prompt / bio section ──────────────────────────────────────────────────────

class _PromptSection extends StatelessWidget {
  final String text;
  final VoidCallback onLike;
  const _PromptSection({required this.text, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).surface2.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ABOUT ME',
                  style: TextStyle(
                    color: AppColors.of(context).textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Bio text
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.of(context).textDark,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
          // Like button row
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
              child: _SectionLikeButton(onTap: onLike),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo section ─────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final String photoUrl;
  final String label;
  final VoidCallback onLike;
  const _PhotoSection({required this.photoUrl, required this.label, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final fullUrl = photoUrl.startsWith('http')
        ? photoUrl
        : '${AppConfig.mediaBaseUrl}$photoUrl';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.of(context).surface,
        border: Border.all(color: AppColors.of(context).surface2.withOpacity(0.4)),
      ),
      clipBehavior: Clip.hardEdge,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWidget(imageUrl: fullUrl, fit: BoxFit.cover),
            Positioned(
              right: 14,
              bottom: 14,
              child: _SectionLikeButton(onTap: onLike),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Interests section ─────────────────────────────────────────────────────────

class _InterestsSection extends StatelessWidget {
  final List<String> interests;
  final VoidCallback onLike;
  const _InterestsSection({required this.interests, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final shown = interests.take(8).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).surface2.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'INTERESTS',
                style: TextStyle(
                  color: AppColors.of(context).textLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shown.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 12),
              child: _SectionLikeButton(onTap: onLike),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section like button ────────────────────────────────────────────────────────

class _SectionLikeButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SectionLikeButton({required this.onTap});

  @override
  State<_SectionLikeButton> createState() => _SectionLikeButtonState();
}

class _SectionLikeButtonState extends State<_SectionLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
