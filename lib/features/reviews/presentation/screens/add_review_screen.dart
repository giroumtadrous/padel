import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/reviews/data/services/review_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddReviewScreen extends StatefulWidget {
  final String bookingId;
  final String venueId;
  final String venueName;

  const AddReviewScreen({
    super.key,
    required this.bookingId,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Your Session'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.venueName,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How was your experience?',
                    style: TextStyle(color: AppColors.textBlueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Star rating
            Text(
              'Your Rating',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starValue = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: starValue <= _rating ? AppColors.gold : AppColors.textHint,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _ratingLabel(_rating),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Comment
            Text(
              'Leave a Comment (Optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share your experience with others...',
              ),
            ),
            const SizedBox(height: 32),

            AppButton(
              label: 'Submit Review',
              isLoading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return 'Poor';
      case 2:
        return 'Below Average';
      case 3:
        return 'Average';
      case 4:
        return 'Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _loading = true);

    try {
      final reviewService = ReviewService();
      await reviewService.submitReview(
        userId: authState.user.uid,
        userDisplayName: authState.user.displayName,
        venueId: widget.venueId,
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted! Thank you.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
