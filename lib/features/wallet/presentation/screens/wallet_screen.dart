import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/wallet/presentation/screens/topup_manual_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _amountCtrl = TextEditingController();
  final _amountFormKey = GlobalKey<FormState>();
  String _selectedMethod = AppConstants.paymentVodafone;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: AppLoadingSpinner(),
          );
        }
        final user = state.user;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('My Wallet'),
            leading: BackButton(onPressed: () => context.pop()),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Balance card — dark navy header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(color: AppColors.textBlueGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'EGP ${user.walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textOnDark,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Loyalty strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.navyLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user.loyaltyDiscountEligible
                                    ? '50% loyalty discount ready to use!'
                                    : '${user.loyaltyBookingCount % AppConstants.loyaltyBookingsRequired}/${AppConstants.loyaltyBookingsRequired} bookings to loyalty reward',
                                style: TextStyle(
                                  color: user.loyaltyDiscountEligible
                                      ? AppColors.gold
                                      : AppColors.textBlueGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Up Wallet', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Add credits to pay for your bookings instantly',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),

                      // Amount entry — top-up is paid by Visa/Mastercard only
                      Form(
                        key: _amountFormKey,
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Amount (EGP)',
                            hintText: 'e.g. 200',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          validator: (v) {
                            final amount = double.tryParse(v ?? '');
                            if (amount == null || amount <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _TopUpMethodOption(
                              icon: Icons.phone_android_rounded,
                              label: 'Vodafone Cash',
                              isSelected: _selectedMethod == AppConstants.paymentVodafone,
                              onTap: () => setState(() => _selectedMethod = AppConstants.paymentVodafone),
                            ),
                            _TopUpMethodOption(
                              icon: Icons.send_rounded,
                              label: 'InstaPay',
                              isSelected: _selectedMethod == AppConstants.paymentInstaPay,
                              onTap: () => setState(() => _selectedMethod = AppConstants.paymentInstaPay),
                            ),
                            _TopUpMethodOption(
                              icon: Icons.credit_card_rounded,
                              label: 'Card (Visa / MC)',
                              isSelected: _selectedMethod == AppConstants.paymentCard,
                              disabled: true,
                              suffix: const Text('Coming soon', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                              onTap: () => setState(() => _selectedMethod = AppConstants.paymentCard),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Continue',
                        onPressed: () {
                          if (!_amountFormKey.currentState!.validate()) return;
                          final amount = double.parse(_amountCtrl.text);
                          if (_selectedMethod == AppConstants.paymentCard) return;

                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TopUpManualScreen(
                              amount: amount,
                              paymentMethod: _selectedMethod,
                            ),
                          ));
                        },
                      ),

                      const SizedBox(height: 32),
                      Text('Transaction History', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      _TransactionPlaceholder(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TransactionPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Your wallet activity will appear here',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TopUpMethodOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool disabled;
  final Widget? suffix;
  final VoidCallback? onTap;

  const _TopUpMethodOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.disabled = false,
    this.suffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: disabled
                    ? AppColors.textHint
                    : isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: disabled ? AppColors.textHint : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            ?suffix,
            if (!disabled)
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textHint,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
