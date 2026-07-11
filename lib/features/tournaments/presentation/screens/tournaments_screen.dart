import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/tournaments/data/models/tournament_model.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_bloc.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_event.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_state.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TournamentsBloc>().add(const LoadTournaments());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: BlocListener<TournamentsBloc, TournamentsState>(
        listener: (context, state) {
          if (state is TournamentsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
          if (state is TournamentJoined) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You\'re in! See you on the court.')),
            );
          }
        },
        child: BlocBuilder<TournamentsBloc, TournamentsState>(
          builder: (context, state) {
            if (state is TournamentsLoading) return const ShimmerList(itemCount: 3, itemHeight: 170);
            if (state is TournamentsError) {
              return AppErrorView(
                message: state.message,
                onRetry: () => context.read<TournamentsBloc>().add(const LoadTournaments()),
              );
            }
            if (state is TournamentsLoaded) {
              if (state.tournaments.isEmpty) {
                return const AppEmptyView(
                  title: 'No tournaments yet',
                  subtitle: 'Check back soon for upcoming padel tournaments!',
                  icon: Icons.emoji_events_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.tournaments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _TournamentCard(tournament: state.tournaments[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  static final _dateFmt = DateFormat('EEE, MMM d · HH:mm');

  const _TournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : '';
    final userSkill = authState is AuthAuthenticated ? authState.user.skillLevel : 0.0;
    final hasJoined = tournament.participantIds.contains(userId);
    final canJoin = tournament.canJoin(userSkill) && !hasJoined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tournament.isFull ? AppColors.divider : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tournament.name, style: Theme.of(context).textTheme.titleLarge)),
              Text(
                '${tournament.participantIds.length}/${tournament.maxParticipants}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tournament.venueName, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              _Chip(Icons.calendar_today_rounded, _dateFmt.format(tournament.startTime)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip(
                Icons.star_rounded,
                '${tournament.minSkillLevel.toStringAsFixed(1)}–${tournament.maxSkillLevel.toStringAsFixed(1)}',
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              _Chip(Icons.payments_outlined, 'EGP ${tournament.entryFee.toInt()} entry'),
              const Spacer(),
              if (hasJoined)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Joined',
                      style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
                )
              else if (canJoin)
                GestureDetector(
                  onTap: () => _confirmJoin(context, userId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Join',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                )
              else if (tournament.isFull)
                const Text('Full', style: TextStyle(color: AppColors.textHint, fontSize: 13))
              else
                const Text('Not eligible', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
            ],
          ),
          if (tournament.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tournament.description,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _confirmJoin(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Tournament'),
        content: Text(
          'Join "${tournament.name}"? EGP ${tournament.entryFee.toInt()} will be deducted from your wallet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TournamentsBloc>().add(
                    JoinTournament(tournamentId: tournament.id, userId: userId),
                  );
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Chip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
