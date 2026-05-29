import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import 'network_image_widget.dart';
import '../utils/app_colors.dart';

class MatchModal extends StatefulWidget {
  final UserModel currentUser;
  final UserModel matchedUser;
  final String matchId;
  final VoidCallback onKeepSwiping;
  final VoidCallback onSendMessage;

  const MatchModal({
    Key? key,
    required this.currentUser,
    required this.matchedUser,
    required this.matchId,
    required this.onKeepSwiping,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  State<MatchModal> createState() => _MatchModalState();
}

class _MatchModalState extends State<MatchModal> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _scaleAnimation =
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () => _slideController.forward());
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A33), AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  // Glow ring around text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Text(
                      "It's a Match!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You and ${widget.matchedUser.name} liked each other',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 44),
            // Photo pair
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProfileCircle(widget.currentUser),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 24),
                  ),
                ),
                _buildProfileCircle(widget.matchedUser),
              ],
            ),
            const SizedBox(height: 56),
            SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: widget.onSendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Send a Message',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: widget.onKeepSwiping,
                      child: Text(
                        'Keep Swiping',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCircle(UserModel user) {
    return Container(
      width: 126,
      height: 126,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: user.firstPhoto.isNotEmpty
            ? NetworkImageWidget(imageUrl: user.firstPhoto, fit: BoxFit.cover)
            : Container(
                color: AppColors.of(context).surface,
                child: Icon(Icons.person, size: 56, color: AppColors.of(context).textMedium),
              ),
      ),
    );
  }
}
