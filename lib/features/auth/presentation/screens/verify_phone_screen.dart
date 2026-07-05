import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/data/services/auth_service.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String? _verificationId;
  bool _sending = false;
  bool _confirming = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && (authState.user.phone ?? '').isNotEmpty) {
      _phoneCtrl.text = authState.user.phone!;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showSnack('Please enter your phone number.');
      return;
    }

    setState(() => _sending = true);
    try {
      await context.read<AuthService>().sendPhoneVerificationCode(
            phone,
            onCodeSent: (verificationId) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _sending = false;
              });
              _startCooldown();
            },
            onFailed: (error) {
              if (!mounted) return;
              setState(() => _sending = false);
              _showSnack(error);
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showSnack('Could not send verification code: $e');
    }
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();
    if (verificationId == null) return;
    if (code.isEmpty) {
      _showSnack('Please enter the code you received.');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _confirming = true);
    try {
      await context.read<AuthService>().confirmPhoneVerificationCode(
            verificationId: verificationId,
            smsCode: code,
            uid: authState.user.uid,
            phoneNumber: _phoneCtrl.text.trim(),
          );
      if (!mounted) return;
      context.read<AuthBloc>().add(const RefreshCurrentUser());
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _skip() {
    context.read<AuthBloc>().add(const SkipPhoneVerification());
    context.go('/venues');
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _verificationId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('Skip'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(const AuthLoggedOut()),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_android_rounded, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify your phone number',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    codeSent
                        ? 'Enter the code we sent to ${_phoneCtrl.text.trim()}'
                        : 'Verifying your number helps venues reach you about your bookings. '
                            'You can skip this for now and verify later from your profile.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _phoneCtrl,
                    enabled: !codeSent,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+201234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (codeSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        prefixIcon: Icon(Icons.sms_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: codeSent ? 'Verify' : 'Send Code',
                    isLoading: _sending || _confirming,
                    onPressed: codeSent ? _confirmCode : _sendCode,
                  ),
                  if (codeSent) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resendCooldown > 0 ? null : _sendCode,
                      child: Text(
                        _resendCooldown > 0 ? 'Resend in $_resendCooldown s' : 'Resend code',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
