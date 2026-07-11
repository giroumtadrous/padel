import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Not blank — this also renders briefly during sign-out, between
        // the auth state flipping and the router finishing the redirect to
        // /login. A bare SizedBox.shrink() here looked like a stuck white
        // screen instead of a loading transition.
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: AppLoadingSpinner(),
          );
        }
        return _ProfileContent(user: state.user);
      },
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  late double _skillLevel;
  late String _preferredSide;

  @override
  void initState() {
    super.initState();
    _skillLevel = widget.user.skillLevel;
    _preferredSide = widget.user.preferredSide;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Navy header
          SliverToBoxAdapter(child: _buildNavyHeader(context, user)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  _buildStatsRow(user),
                  const SizedBox(height: 20),

                  // Wallet card
                  _buildWalletCard(context, user),
                  const SizedBox(height: 16),

                  if (!user.phoneVerified) ...[
                    _buildPhoneVerificationBanner(context),
                    const SizedBox(height: 16),
                  ],

                  // Loyalty card
                  _buildLoyaltyCard(context, user),
                  const SizedBox(height: 16),

                  // Favorites
                  _buildSection(
                    title: 'Favorites',
                    icon: Icons.favorite_rounded,
                    iconColor: AppColors.primary,
                    child: Text(
                      '${user.favoriteVenueIds.length} saved venue${user.favoriteVenueIds.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Skill level
                  _buildSection(
                    title: 'Skill Level',
                    icon: Icons.sports_tennis_rounded,
                    iconColor: AppColors.secondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.skillLevel.toStringAsFixed(1),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_skillLabel(user.skillLevel),
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        if (user.pendingSkillLevel != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Text(
                                  'Request pending admin review: ${user.pendingSkillLevel!.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppColors.primary,
                              thumbColor: AppColors.primary,
                              inactiveTrackColor: AppColors.divider,
                              overlayColor: AppColors.primary.withValues(alpha: 0.12),
                            ),
                            child: Slider(
                              value: _skillLevel,
                              min: AppConstants.minSkillLevel,
                              max: AppConstants.maxSkillLevel,
                              divisions: 12,
                              onChanged: (v) => setState(() => _skillLevel = v),
                            ),
                          ),
                          if (_skillLevel != user.skillLevel)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _requestSkillLevel,
                                child: const Text('Request Verification'),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preferred side
                  _buildSection(
                    title: 'Preferred Side',
                    icon: Icons.swap_horiz_rounded,
                    iconColor: AppColors.secondary,
                    child: Row(
                      children: [
                        _SideOption(
                          label: 'Forehand',
                          icon: Icons.arrow_forward_rounded,
                          isSelected: _preferredSide == AppConstants.sideForerhand,
                          onTap: () => setState(
                              () => _preferredSide = AppConstants.sideForerhand),
                        ),
                        const SizedBox(width: 12),
                        _SideOption(
                          label: 'Backhand',
                          icon: Icons.arrow_back_rounded,
                          isSelected: _preferredSide == AppConstants.sideBackhand,
                          onTap: () => setState(
                              () => _preferredSide = AppConstants.sideBackhand),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Admin card
                  if (user.hasAdminAccess) ...[
                    _buildAdminCard(context),
                    const SizedBox(height: 16),
                  ],

                  // Save button
                  AppButton(
                    label: 'Save Changes',
                    onPressed: _saveChanges,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Sign Out',
                    isOutlined: true,
                    onPressed: () => context.read<AuthBloc>().add(const AuthLoggedOut()),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavyHeader(BuildContext context, UserModel user) {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final authBloc = context.read<AuthBloc>();
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                // Pop the dialog *before* dispatching sign-out —
                                // AuthLoggedOut flips auth state, which makes
                                // the router immediately tear down this whole
                                // authenticated route tree. Popping after that
                                // teardown has already started hits a stale
                                // element and crashes with a lifecycle assertion.
                                //
                                // Must use dialogContext (not the header's own
                                // context) — showDialog pushes onto the root
                                // navigator, but this screen lives inside a
                                // StatefulShellRoute branch with its own nested
                                // navigator. Navigator.pop(context) would pop
                                // that branch navigator instead (a no-op, since
                                // there's nothing pushed there), leaving the
                                // dialog's route stuck on the root navigator
                                // while go_router swaps the page stack out from
                                // under it — that's what produced the blank
                                // white screen instead of landing on /login.
                                Navigator.pop(dialogContext);
                                authBloc.add(const AuthLoggedOut());
                              },
                              child: const Text('Sign Out',
                                  style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.textBlueGrey, fontSize: 13),
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 30,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(color: AppColors.textBlueGrey, fontSize: 12),
              ),
              if (user.isAdmin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(UserModel user) {
    return Row(
      children: [
        _StatBox(value: user.skillLevel.toStringAsFixed(1), label: 'Skill'),
        _StatBox(value: '${user.matchesPlayed}', label: 'Matches'),
        _StatBox(
            value: user.preferredSide == AppConstants.sideForerhand ? 'FH' : 'BH',
            label: 'Side'),
        _StatBox(
            value: '${user.favoriteVenueIds.length}', label: 'Favorites'),
      ],
    );
  }

  Widget _buildWalletCard(BuildContext context, UserModel user) {
    return GestureDetector(
      onTap: () => context.push('/wallet'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(color: AppColors.textBlueGrey, fontSize: 12),
                  ),
                  Text(
                    'EGP ${user.walletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textBlueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneVerificationBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/verify-phone'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_android_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phone not verified',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tap to verify your number',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context, UserModel user) {
    final progress = (user.loyaltyBookingCount % AppConstants.loyaltyBookingsRequired) /
        AppConstants.loyaltyBookingsRequired;
    final remaining = AppConstants.loyaltyBookingsRequired -
        (user.loyaltyBookingCount % AppConstants.loyaltyBookingsRequired);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Loyalty Card',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (user.loyaltyDiscountEligible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '50% OFF Ready!',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: user.loyaltyDiscountEligible ? 1.0 : progress,
              backgroundColor: AppColors.divider,
              color: AppColors.gold,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.loyaltyDiscountEligible
                ? 'Discount applied on your next booking!'
                : '$remaining more booking${remaining == 1 ? '' : 's'} to earn 50% off',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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

  Widget _buildAdminCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/admin'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.navy,
              AppColors.secondary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.textOnDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    'Manage courts & view revenue',
                    style: TextStyle(color: AppColors.textBlueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textBlueGrey),
          ],
        ),
      ),
    );
  }

  void _saveChanges() {
    context.read<AuthBloc>().add(AuthProfileUpdated(
          preferredSide: _preferredSide,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  void _requestSkillLevel() {
    context.read<AuthBloc>().add(RequestSkillLevelChange(_skillLevel));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skill level change submitted for admin review')),
    );
  }

  String _skillLabel(double level) {
    if (level < 2.0) return 'Beginner';
    if (level < 3.0) return 'Novice';
    if (level < 4.0) return 'Intermediate';
    if (level < 5.0) return 'Advanced';
    if (level < 6.0) return 'Expert';
    return 'Professional';
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SideOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
