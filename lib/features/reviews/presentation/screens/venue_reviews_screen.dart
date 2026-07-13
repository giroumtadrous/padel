import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/reviews/data/models/review_model.dart';
import 'package:padel/features/reviews/data/services/review_service.dart';

/// Admin-facing view of everything players have said about this venue after
/// their sessions — reviews are submitted from BookingHistoryScreen's "Rate"
/// button, this is just the read side for the venue owner.
class VenueReviewsScreen extends StatelessWidget {
  final String venueId;
  const VenueReviewsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reviews'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: context.read<ReviewService>().getVenueReviews(venueId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const AppLoadingSpinner();
          }
          final reviews = snapshot.data!;
          if (reviews.isEmpty) {
            return const AppEmptyView(
              title: 'No reviews yet',
              subtitle: 'Reviews players leave after their sessions will appear here',
              icon: Icons.star_outline_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  static final _dateFmt = DateFormat('MMM d, yyyy');

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.userDisplayName, style: Theme.of(context).textTheme.titleLarge),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.gold,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_dateFmt.format(review.createdAt), style: Theme.of(context).textTheme.bodySmall),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
