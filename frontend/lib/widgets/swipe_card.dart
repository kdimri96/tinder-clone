import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import 'network_image_widget.dart';
import 'report_dialog.dart';

class SwipeCard extends StatefulWidget {
  final UserModel user;
  final double? swipeProgress;
  final bool isTopCard;

  const SwipeCard({
    Key? key,
    required this.user,
    this.swipeProgress,
    this.isTopCard = false,
  }) : super(key: key);

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  int _currentPhoto = 0;

  void _nextPhoto() {
    if (_currentPhoto < widget.user.photos.length - 1) {
      setState(() => _currentPhoto++);
    }
  }

  void _prevPhoto() {
    if (_currentPhoto > 0) {
      setState(() => _currentPhoto--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.user.photos;
    final hasMany = photos.length > 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Current photo
            _buildPhoto(photos),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(gradient: AppTheme.cardGradient),
            ),

            // Tap zones for photo navigation — placed before overlays that
            // also need taps so the Stack Z-order gives those priority.
            if (hasMany)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _prevPhoto,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _nextPhoto,
                      ),
                    ),
                  ],
                ),
              ),

            // Photo progress bars (Tinder-style) at top
            if (hasMany)
              Positioned(
                top: 10,
                left: 8,
                right: 8,
                child: _buildProgressBars(photos.length),
              ),

            // Like / Nope labels
            if (widget.isTopCard && widget.swipeProgress != null)
              _buildSwipeLabels(),

            // More options button — placed AFTER tap zones so it wins hit test
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => showReportBottomSheet(context, widget.user),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
              ),
            ),

            // User info at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildUserInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.person, size: 80, color: Colors.grey),
      );
    }
    final idx = _currentPhoto.clamp(0, photos.length - 1);
    return NetworkImageWidget(
      key: ValueKey(photos[idx]),
      imageUrl: photos[idx],
      fit: BoxFit.cover,
    );
  }

  Widget _buildProgressBars(int count) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: i == _currentPhoto
                  ? Colors.white
                  : Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSwipeLabels() {
    final progress = widget.swipeProgress ?? 0;
    return Stack(
      children: [
        if (progress > 0.1)
          Positioned(
            top: 40,
            left: 20,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.success, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIKE',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        if (progress < -0.1)
          Positioned(
            top: 40,
            right: 20,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.error, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NOPE',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfo() {
    final user = widget.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                user.age != null ? '${user.name}, ${user.age}' : user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (user.isOnline)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
          ],
        ),
        if (user.job != null && user.job!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.work, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(user.job!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
        if (user.distance != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                '${(user.distance! / 1000).toStringAsFixed(1)} km away',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
        if (user.bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            user.bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
        if (user.interests.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: user.interests.take(3).map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54),
                ),
                child: Text(
                  interest,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
