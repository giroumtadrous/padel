import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginWithPhonePassword(
        phoneNumber: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _buildHeader(context),
                const SizedBox(height: 40),
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 8),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) => AppButton(
                    label: 'Sign In',
                    onPressed: _submit,
                    isLoading: state is AuthLoading,
                  ),
                ),
                // ── Inline error banner ──────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final message = state is AuthError ? state.message : null;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: message != null
                          ? _ErrorBanner(
                              key: ValueKey(message),
                              message: message,
                              onDismiss: () => context.read<AuthBloc>().add(
                                const AuthDismissError(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    );
                  },
                ),
                // ────────────────────────────────────────────────────────
                const SizedBox(height: 32),
                _buildSignUpLink(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.sports_tennis_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        Text('Welcome back', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 6),
        Text(
          'Sign in to book your court',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Phone number',
        hintText: '+201234567890',
        prefixIcon: Icon(Icons.phone_outlined, size: 20),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Phone number is required';
        if (!v.trim().startsWith('+'))
          return 'Use international format, e.g. +201234567890';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () => context.go('/register'),
          child: const Text('Sign Up'),
        ),
      ],
    );
  }
}

// ── Inline error banner widget ───────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          border: Border.all(color: AppColors.error.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
