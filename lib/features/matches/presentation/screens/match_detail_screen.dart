import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';
import 'package:padel/features/matches/data/services/matchmaking_service.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/matches/presentation/bloc/matches_event.dart';
import 'package:padel/features/matches/presentation/bloc/matches_state.dart';

class MatchDetailScreen extends StatelessWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OpenMatchModel>(
      stream: context.read<MatchmakingService>().getMatchStream(matchId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const AppLoadingSpinner());
        }
        return _MatchDetailContent(match: snap.data!);
      },
    );
  }
}

class _MatchDetailContent extends StatelessWidget {
  final OpenMatchModel match;
  static final _dateFmt = DateFormat('EEEE, MMMM d');
  static final _timeFmt = DateFormat('HH:mm');

  const _MatchDetailContent({required this.match});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : '';
    final userSkill = authState is AuthAuthenticated ? authState.user.skillLevel : 0.0;
    final hasJoined = match.participantIds.contains(userId);
    final isOrganizer = match.organizerId == userId;
    final canJoin = match.canJoin(userSkill) && !hasJoined && !isOrganizer;

    return BlocListener<MatchesBloc, MatchesState>(
      listener: (context, state) {
        if (state is MatchJoined) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully joined the match!')),
          );
        } else if (state is MatchesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Match Details'),
          leading: BackButton(onPressed: () => context.go('/matches')),
          actions: [
            if (isOrganizer)
              IconButton(
                onPressed: () => _cancelMatch(context, userId),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildInfoCard(context),
              const SizedBox(height: 20),
              _buildSkillRange(context),
              const SizedBox(height: 20),
              _buildParticipants(context),
              if (match.description.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildDescription(context),
              ],
              const SizedBox(height: 32),
              if (hasJoined)
                AppButton(
                  label: 'Leave Match',
                  isOutlined: true,
                  onPressed: () => context.read<MatchesBloc>().add(
                        LeaveMatch(matchId: match.id, userId: userId),
                      ),
                )
              else if (canJoin)
                AppButton(
                  label: 'Join Match — EGP ${match.pricePerPlayer.toInt()}',
                  onPressed: () => context.read<MatchesBloc>().add(
                        JoinMatch(matchId: match.id, userId: userId, userSkillLevel: userSkill),
                      ),
                )
              else if (match.isFull)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Match is Full', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else if (!match.canJoin(userSkill))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Your skill level ($userSkill) doesn\'t meet the requirements',
                        style: const TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.venueName, style: Theme.of(context).textTheme.displayMedium),
              Text(match.courtName, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        _SlotCircle(filled: match.filledSlots, total: match.totalSlots),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _Row(Icons.calendar_today_rounded, 'Date', _dateFmt.format(match.startTime)),
          const Divider(height: 16),
          _Row(Icons.access_time_rounded, 'Time',
              '${_timeFmt.format(match.startTime)} – ${_timeFmt.format(match.endTime)}'),
          const Divider(height: 16),
          _Row(Icons.payments_outlined, 'Per Player', 'EGP ${match.pricePerPlayer.toInt()}'),
          const Divider(height: 16),
          _Row(Icons.person_outline_rounded, 'Organizer', match.organizerName),
        ],
      ),
    );
  }

  Widget _buildSkillRange(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Text('Required Skill Level', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(
            '${match.minSkillLevel.toStringAsFixed(1)} – ${match.maxSkillLevel.toStringAsFixed(1)}',
            style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipants(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Players (${match.filledSlots}/${match.totalSlots})',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: List.generate(match.totalSlots, (i) {
            final isFilled = i < match.filledSlots;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 52,
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.primary.withOpacity(0.15) : AppColors.card,
                  border: Border.all(
                    color: isFilled ? AppColors.primary : AppColors.divider,
                    width: isFilled ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFilled ? Icons.person_rounded : Icons.person_add_outlined,
                  color: isFilled ? AppColors.primary : AppColors.textHint,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Note from organizer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(match.description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  void _cancelMatch(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cancel Match'),
        content: const Text('Cancel this open match? All players will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<MatchesBloc>().add(CancelOpenMatch(matchId: match.id, organizerId: userId));
              context.go('/matches');
            },
            child: const Text('Cancel Match', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SlotCircle extends StatelessWidget {
  final int filled;
  final int total;
  const _SlotCircle({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: filled / total,
            strokeWidth: 4,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(
              filled >= total ? AppColors.error : AppColors.primary,
            ),
          ),
          Text(
            '$filled/$total',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
