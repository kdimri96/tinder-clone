import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';

// Razorpay disabled during testing

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PremiumProvider>().fetchPlans();
    });
  }

  Future<void> _purchasePlan(PlanModel plan) async {
    AppNotification.info(context, 'Payments coming soon! Testing in progress.');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PremiumProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.plans.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 64, color: AppTheme.textLight),
                        const SizedBox(height: 12),
                        Text('Could not load plans',
                            style: TextStyle(color: AppTheme.textMedium)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: provider.fetchPlans,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (provider.isPremium || provider.isUnlimitedLikes || provider.isBoosted)
                        _buildActiveBadge(provider),
                      const SizedBox(height: 8),
                      ...provider.plans.map((plan) => _PlanCard(
                            plan: plan,
                            isPurchasing: provider.isPurchasing,
                            onTap: () => _purchasePlan(plan),
                          )),
                      const SizedBox(height: 16),
                      _buildFooterNote(),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary,
                Color(0xFFAA3DFF),
                AppTheme.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KneedYou Gold',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supercharge your dating life',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBadge(PremiumProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You have active premium features!',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'Payments are secure and processed by Razorpay. '
        'Plans auto-expire and do not renew automatically.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textLight, fontSize: 12, height: 1.5),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final bool isPurchasing;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isPurchasing,
    required this.onTap,
  });

  static const _featureMap = {
    'boost': _PlanMeta(
      icon: Icons.bolt,
      color: Color(0xFF7B5EA7),
      title: 'Profile Boost',
      subtitle: 'Be the top profile for 24 hours',
      perks: ['Top of the stack for 24h', '10× more profile views', 'More matches guaranteed'],
      badge: null,
    ),
    'unlimited_likes': _PlanMeta(
      icon: Icons.favorite,
      color: AppTheme.secondary,
      title: 'Unlimited Likes',
      subtitle: 'Swipe right as much as you want',
      perks: ['No daily like limit', 'Like everyone you\'re interested in', 'Valid for 30 days'],
      badge: 'Popular',
    ),
    'premium': _PlanMeta(
      icon: Icons.workspace_premium,
      color: Color(0xFFFFAA00),
      title: 'KneedYou Gold',
      subtitle: 'The full premium experience',
      perks: [
        'Unlimited Likes for 30 days',
        'Profile Boost included',
        'See who liked you',
        'Priority in discovery'
      ],
      badge: 'Best Value',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _featureMap[plan.feature] ??
        _PlanMeta(
          icon: Icons.star,
          color: AppTheme.primary,
          title: plan.description,
          subtitle: '',
          perks: [],
          badge: null,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: meta.color.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: meta.color.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: meta.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(meta.icon, color: meta.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            meta.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.amountDisplay,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: meta.color,
                          ),
                        ),
                        Text(
                          plan.durationDays == 1 ? '1 day' : '${plan.durationDays} days',
                          style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...meta.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: meta.color),
                          const SizedBox(width: 8),
                          Text(perk, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPurchasing ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: meta.color.withOpacity(0.5),
                    ),
                    child: isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            kIsWeb ? 'Available on Mobile App' : 'Get ${meta.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (meta.badge != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meta.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanMeta {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> perks;
  final String? badge;

  const _PlanMeta({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.perks,
    required this.badge,
  });
}
