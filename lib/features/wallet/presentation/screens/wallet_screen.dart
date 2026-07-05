import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_event.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

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

                      // Top-up amount grid
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: AppConstants.walletTopUpAmounts
                            .map((amount) => _TopUpCard(amount: amount))
                            .toList(),
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

class _TopUpCard extends StatelessWidget {
  final double amount;
  const _TopUpCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _topUp(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'EGP',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              amount.toInt().toString(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _topUp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: Text('Add EGP ${amount.toInt()} to your wallet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(TopUpWallet(amount));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('EGP ${amount.toInt()} added to your wallet!')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
