import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Need a hand with ${AppConstants.appName}?',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Here are the most common things we can help you with: booking a court, changing a booking, payments, profile updates, and account access.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _SupportCard(
            icon: Icons.calendar_month_outlined,
            title: 'Booking Help',
            description: 'Questions about booking slots, cancellations, or rescheduling.',
          ),
          _SupportCard(
            icon: Icons.payments_outlined,
            title: 'Payments',
            description: 'Issues with deposits, manual transfer receipts, or wallet balance.',
          ),
          _SupportCard(
            icon: Icons.person_outline,
            title: 'Account & Profile',
            description: 'Need help with your profile, phone verification, or login.',
          ),
          _SupportCard(
            icon: Icons.support_agent_rounded,
            title: 'Contact Your Venue',
            description: 'For venue-specific questions, contact the venue admin or staff directly from your booking details.',
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SupportCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}