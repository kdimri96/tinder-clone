import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../widgets/network_image_widget.dart';

/// Full-screen profile viewer for a matched user, opened from the chat screen.
class UserProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photos = user.photos;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Photo header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.55,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isEmpty
                  ? Container(
                      color: AppTheme.surface2,
                      child: const Icon(Icons.person, size: 80, color: AppTheme.textLight),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Current photo
                        GestureDetector(
                          onTapDown: (details) {
                            final half = MediaQuery.of(context).size.width / 2;
                            setState(() {
                              if (details.localPosition.dx < half) {
                                _photoIndex = (_photoIndex - 1).clamp(0, photos.length - 1);
                              } else {
                                _photoIndex = (_photoIndex + 1).clamp(0, photos.length - 1);
                              }
                            });
                          },
                          child: NetworkImageWidget(
                            imageUrl: photos[_photoIndex],
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Dot indicators
                        if (photos.length > 1)
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(photos.length, (i) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _photoIndex ? 20 : 6,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i == _photoIndex
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                        // Bottom gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 120,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        // Name + age overlay
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Text(
                            user.age != null ? '${user.name}, ${user.age}' : user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Profile details ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Online status
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.isOnline ? AppTheme.success : AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.isOnline ? 'Active now' : 'Recently active',
                        style: TextStyle(
                          color: user.isOnline ? AppTheme.success : AppTheme.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Bio
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Section(
                      icon: Icons.person_outline,
                      title: 'About',
                      child: Text(
                        user.bio,
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Job & school
                  if ((user.job?.isNotEmpty == true) || (user.school?.isNotEmpty == true)) ...[
                    const SizedBox(height: 20),
                    _Section(
                      icon: Icons.info_outline,
                      title: 'Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user.job?.isNotEmpty == true)
                            _DetailRow(Icons.work_outline, user.job!),
                          if (user.school?.isNotEmpty == true)
                            _DetailRow(Icons.school_outlined, user.school!),
                        ],
                      ),
                    ),
                  ],

                  // Interests
                  if (user.interests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _Section(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Interests',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.3)),
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
                    ),
                  ],

                  // Extra photos gallery
                  if (photos.length > 1) ...[
                    const SizedBox(height: 20),
                    _Section(
                      icon: Icons.photo_library_outlined,
                      title: 'Photos',
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: () => setState(() => _photoIndex = i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: NetworkImageWidget(
                              imageUrl: photos[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surface2.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
