import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/skill_requests/data/models/skill_request_model.dart';
import 'package:padel/features/skill_requests/data/services/skill_request_service.dart';

class SkillRequestsScreen extends StatelessWidget {
  const SkillRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Skill Level Requests'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: StreamBuilder<List<SkillRequestModel>>(
        stream: context.read<SkillRequestService>().getPendingRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const AppLoadingSpinner();
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RequestCard(request: requests[i]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SkillRequestModel request;
  static final _dateFmt = DateFormat('MMM d, yyyy · HH:mm');

  const _RequestCard({required this.request});

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
          Text(request.userName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(_dateFmt.format(request.createdAt), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                request.currentLevel.toStringAsFixed(1),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textHint),
              ),
              Text(
                request.requestedLevel.toStringAsFixed(1),
                style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.read<SkillRequestService>().rejectRequest(request.id),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.read<SkillRequestService>().approveRequest(request.id),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
