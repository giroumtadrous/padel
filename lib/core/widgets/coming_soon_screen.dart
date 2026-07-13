import 'package:flutter/material.dart';
import 'package:padel/core/constants/app_colors.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.hourglass_top_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.textHint),
              const SizedBox(height: 20),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
