import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padel/core/constants/app_colors.dart';

class CancellationPolicyDialog extends StatefulWidget {
  final VoidCallback? onAgree;

  const CancellationPolicyDialog({
    super.key,
    this.onAgree,
  });

  @override
  State<CancellationPolicyDialog> createState() =>
      _CancellationPolicyDialogState();
}

class _CancellationPolicyDialogState extends State<CancellationPolicyDialog> {
  bool _doNotShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cancellation Policy',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please note our cancellation policy:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PolicyItem(
                    icon: Icons.check_circle_outline,
                    title: 'Cancel 6+ Hours Before',
                    subtitle:
                        'Full refund to wallet (minus deposit) if cancelled 6 hours or more before your booking time.',
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _PolicyItem(
                    icon: Icons.info_outline,
                    title: 'Cancel Within 6 Hours',
                    subtitle:
                        'No refund if cancelled less than 6 hours before your booking time. Payment is forfeited.',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  _PolicyItem(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Deposit Non-Refundable',
                    subtitle:
                        'Deposit amount is non-refundable under any circumstances.',
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _doNotShowAgain,
                  onChanged: (value) {
                    setState(() => _doNotShowAgain = value ?? false);
                  },
                  activeColor: AppColors.primary,
                ),
                const Expanded(
                  child: Text(
                    'Do not show again',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (_doNotShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dontShowCancellationPolicy', true);
            }
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_doNotShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dontShowCancellationPolicy', true);
            }
            widget.onAgree?.call();
            if (mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text(
            'I Understand',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _PolicyItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the cancellation policy dialog if user hasn't disabled it
Future<bool?> showCancellationPolicyDialog(
  BuildContext context, {
  VoidCallback? onAgree,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final dontShow = prefs.getBool('dontShowCancellationPolicy') ?? false;

  if (dontShow) {
    onAgree?.call();
    return true;
  }

  if (context.mounted) {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancellationPolicyDialog(onAgree: onAgree),
    );
  }
  return null;
}
