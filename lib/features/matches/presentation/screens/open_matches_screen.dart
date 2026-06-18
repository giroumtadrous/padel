import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/matches/data/models/open_match_model.dart';
import 'package:padel/features/matches/presentation/bloc/matches_bloc.dart';
import 'package:padel/features/matches/presentation/bloc/matches_event.dart';
import 'package:padel/features/matches/presentation/bloc/matches_state.dart';

class OpenMatchesScreen extends StatefulWidget {
  const OpenMatchesScreen({super.key});

  @override
  State<OpenMatchesScreen> createState() => _OpenMatchesScreenState();
}

class _OpenMatchesScreenState extends State<OpenMatchesScreen> {
  double? _filterMin;
  double? _filterMax;

  @override
  void initState() {
    super.initState();
    context.read<MatchesBloc>().add(const LoadOpenMatches());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Matches'),
        actions: [
          IconButton(
            onPressed: _showFilterSheet,
            icon: Badge(
              isLabelVisible: _filterMin != null || _filterMax != null,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
      body: BlocBuilder<MatchesBloc, MatchesState>(
        builder: (context, state) {
          if (state is MatchesLoading) return const ShimmerList(itemCount: 3, itemHeight: 160);
          if (state is MatchesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<MatchesBloc>().add(const LoadOpenMatches()),
            );
          }
          if (state is MatchesLoaded) {
            if (state.matches.isEmpty) {
              return const AppEmptyView(
                title: 'No open matches',
                subtitle: 'Book a court and open it to the community!',
                icon: Icons.group_outlined,
              );
            }
            return _MatchList(matches: state.matches);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showFilterSheet() {
    double min = _filterMin ?? AppConstants.minSkillLevel;
    double max = _filterMax ?? AppConstants.maxSkillLevel;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by Skill Level', style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                '${min.toStringAsFixed(1)} – ${max.toStringAsFixed(1)}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
              ),
              RangeSlider(
                values: RangeValues(min, max),
                min: AppConstants.minSkillLevel,
                max: AppConstants.maxSkillLevel,
                divisions: 12,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.divider,
                onChanged: (r) => setModal(() {
                  min = r.start;
                  max = r.end;
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterMin = null;
                          _filterMax = null;
                        });
                        context.read<MatchesBloc>().add(const LoadOpenMatches());
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterMin = min;
                          _filterMax = max;
                        });
                        context.read<MatchesBloc>().add(
                              LoadOpenMatches(filterMinSkill: min, filterMaxSkill: max),
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<OpenMatchModel> matches;
  const _MatchList({required this.matches});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _MatchCard(match: matches[i]),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final OpenMatchModel match;
  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('HH:mm');

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : '';
    final userSkill = authState is AuthAuthenticated ? authState.user.skillLevel : 0.0;
    final hasJoined = match.participantIds.contains(userId);
    final canJoin = match.canJoin(userSkill) && !hasJoined;

    return GestureDetector(
      onTap: () => context.go('/matches/${match.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: match.isFull ? AppColors.divider : AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(match.venueName, style: Theme.of(context).textTheme.titleLarge)),
                _SlotIndicator(filled: match.filledSlots, total: match.totalSlots),
              ],
            ),
            const SizedBox(height: 4),
            Text(match.courtName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                _Chip(Icons.calendar_today_rounded, _dateFmt.format(match.startTime)),
                const SizedBox(width: 8),
                _Chip(Icons.access_time_rounded,
                    '${_timeFmt.format(match.startTime)} – ${_timeFmt.format(match.endTime)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Chip(Icons.star_rounded, '${match.minSkillLevel.toStringAsFixed(1)}–${match.maxSkillLevel.toStringAsFixed(1)}',
                    color: AppColors.secondary),
                const SizedBox(width: 8),
                _Chip(Icons.payments_outlined, 'EGP ${match.pricePerPlayer.toInt()}/player'),
                const Spacer(),
                if (hasJoined)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Joined', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
                  )
                else if (canJoin)
                  GestureDetector(
                    onTap: () => context.read<MatchesBloc>().add(
                          JoinMatch(matchId: match.id, userId: userId, userSkillLevel: userSkill),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Join', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  )
                else if (match.isFull)
                  const Text('Full', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ],
            ),
            if (match.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                match.description,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotIndicator extends StatelessWidget {
  final int filled;
  final int total;

  const _SlotIndicator({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppColors.primary : AppColors.divider,
          ),
        );
      }),
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
