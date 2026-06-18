import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) return const SizedBox.shrink();
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text('Save'),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(const AuthLoggedOut());
                        Navigator.pop(context);
                      },
                      child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatar(user),
            const SizedBox(height: 24),
            _buildStatsRow(user),
            const SizedBox(height: 28),
            _buildSection(
              title: 'Skill Level',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _skillLevel.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_skillLabel(_skillLevel), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      inactiveTrackColor: AppColors.divider,
                      overlayColor: AppColors.primary.withOpacity(0.12),
                    ),
                    child: Slider(
                      value: _skillLevel,
                      min: AppConstants.minSkillLevel,
                      max: AppConstants.maxSkillLevel,
                      divisions: 12,
                      onChanged: (v) => setState(() => _skillLevel = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Preferred Side',
              child: Row(
                children: [
                  _SideOption(
                    label: 'Forehand',
                    icon: Icons.arrow_forward_rounded,
                    isSelected: _preferredSide == AppConstants.sideForerhand,
                    onTap: () => setState(() => _preferredSide = AppConstants.sideForerhand),
                  ),
                  const SizedBox(width: 12),
                  _SideOption(
                    label: 'Backhand',
                    icon: Icons.arrow_back_rounded,
                    isSelected: _preferredSide == AppConstants.sideBackhand,
                    onTap: () => setState(() => _preferredSide = AppConstants.sideBackhand),
                  ),
                ],
              ),
            ),
            if (user.isAdmin) ...[
              const SizedBox(height: 16),
              _buildAdminCard(context),
            ],
            const SizedBox(height: 32),
            AppButton(
              label: 'Sign Out',
              isOutlined: true,
              onPressed: () => context.read<AuthBloc>().add(const AuthLoggedOut()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primary,
          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(
                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 36, color: Colors.black, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(user.displayName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
        if (user.isAdmin)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              border: Border.all(color: AppColors.secondary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Admin',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow(UserModel user) {
    return Row(
      children: [
        _StatBox(value: user.skillLevel.toStringAsFixed(1), label: 'Rating'),
        _StatBox(value: '${user.matchesPlayed}', label: 'Matches'),
        _StatBox(value: user.preferredSide == AppConstants.sideForerhand ? 'FH' : 'BH', label: 'Side'),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
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
            colors: [AppColors.secondary.withOpacity(0.2), AppColors.primary.withOpacity(0.1)],
          ),
          border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Dashboard', style: Theme.of(context).textTheme.titleMedium),
                  Text('Manage courts & view revenue', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _saveChanges() {
    context.read<AuthBloc>().add(AuthProfileUpdated(
          skillLevel: _skillLevel,
          preferredSide: _preferredSide,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
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

  const _SideOption({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
