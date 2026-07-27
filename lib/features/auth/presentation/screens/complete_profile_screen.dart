import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  double _skillLevel = _skillLevels['Intermediate']!;
  String _preferredSide = AppConstants.sideForerhand;

  static const _skillLevels = {
    'Beginner': 1.5,
    'Intermediate': 3.5,
    'Advanced': 5.0,
    'Expert': 6.5,
  };

  void _submit() {
    context.read<AuthBloc>().add(AuthProfileUpdated(
          preferredSide: _preferredSide,
          skillLevel: _skillLevel,
        ));
  }

  void _logout() {
    context.read<AuthBloc>().add(const AuthLoggedOut());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
          return;
        }

        if (state is AuthAuthenticated && state.user.preferredSide.isNotEmpty && state.user.skillLevel > 0) {
          context.go(state.user.hasAdminAccess ? '/admin' : '/venues');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign Out',
              onPressed: _logout,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome to ${AppConstants.appName}!', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Help us customize your matchmaking experience by choosing your side and skill level.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 36),
              Text('Skill Level', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _skillLevels.entries.map((entry) {
                  return _OptionChip(
                    label: entry.key,
                    isSelected: _skillLevel == entry.value,
                    onTap: () => setState(() => _skillLevel = entry.value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text('Preferred Side', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  _OptionChip(
                    label: 'Right Side',
                    isSelected: _preferredSide == AppConstants.sideForerhand,
                    onTap: () => setState(() => _preferredSide = AppConstants.sideForerhand),
                  ),
                  const SizedBox(width: 12),
                  _OptionChip(
                    label: 'Left Side',
                    isSelected: _preferredSide == AppConstants.sideBackhand,
                    onTap: () => setState(() => _preferredSide = AppConstants.sideBackhand),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) => AppButton(
                  label: 'Save & Continue',
                  onPressed: _submit,
                  isLoading: state is AuthLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
