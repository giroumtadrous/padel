import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/tournaments/data/models/tournament_model.dart';
import 'package:padel/features/tournaments/data/services/tournament_service.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_bloc.dart';
import 'package:padel/features/tournaments/presentation/bloc/tournaments_event.dart';
import 'package:padel/features/venues/data/models/venue_model.dart';

class ManageTournamentsScreen extends StatefulWidget {
  const ManageTournamentsScreen({super.key});

  @override
  State<ManageTournamentsScreen> createState() => _ManageTournamentsScreenState();
}

class _ManageTournamentsScreenState extends State<ManageTournamentsScreen> {
  List<TournamentModel> _tournaments = [];
  List<VenueModel> _venues = [];
  bool _loading = true;

  String get _adminId {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.uid : '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adminService = context.read<AdminService>();
    final tournamentService = context.read<TournamentService>();
    final venues = await adminService.getAdminVenues(_adminId);
    final tournaments = await tournamentService.getAdminTournaments(_adminId);
    if (!mounted) return;
    setState(() {
      _venues = venues;
      _tournaments = tournaments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Tournaments'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(onPressed: _showCreateSheet, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const AppLoadingSpinner()
          : _tournaments.isEmpty
              ? const Center(child: Text('No tournaments yet. Add one!'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tournaments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _TournamentAdminCard(
                    tournament: _tournaments[i],
                    onCancel: () async {
                      context.read<TournamentsBloc>().add(CancelTournament(
                            tournamentId: _tournaments[i].id,
                            adminId: _adminId,
                          ));
                      await _load();
                    },
                  ),
                ),
    );
  }

  void _showCreateSheet() {
    if (_venues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need a managed venue before creating a tournament')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '100');
    final maxCtrl = TextEditingController(text: '16');
    VenueModel selectedVenue = _venues.first;
    DateTime startTime = DateTime.now().add(const Duration(days: 7));
    double minSkill = 1.0;
    double maxSkill = 7.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Tournament', style: Theme.of(ctx).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tournament Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<VenueModel>(
                  value: selectedVenue,
                  decoration: const InputDecoration(labelText: 'Venue'),
                  dropdownColor: AppColors.card,
                  items: _venues
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedVenue = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: feeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Entry Fee (EGP)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Max Participants'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date & Time'),
                  subtitle: Text(DateFormat('EEE, MMM d, yyyy · HH:mm').format(startTime)),
                  trailing: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: startTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date == null) return;
                    if (!ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(startTime),
                    );
                    if (time == null) return;
                    setSheetState(() {
                      startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Skill range: ${minSkill.toStringAsFixed(1)} – ${maxSkill.toStringAsFixed(1)}',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                ),
                RangeSlider(
                  values: RangeValues(minSkill, maxSkill),
                  min: 1.0,
                  max: 7.0,
                  divisions: 12,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  onChanged: (r) => setSheetState(() {
                    minSkill = r.start;
                    maxSkill = r.end;
                  }),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Create Tournament',
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final tournament = TournamentModel(
                      id: '',
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      venueId: selectedVenue.id,
                      venueName: selectedVenue.name,
                      adminId: _adminId,
                      startTime: startTime,
                      entryFee: double.tryParse(feeCtrl.text) ?? 0,
                      maxParticipants: int.tryParse(maxCtrl.text) ?? 16,
                      minSkillLevel: minSkill,
                      maxSkillLevel: maxSkill,
                      createdAt: DateTime.now(),
                    );
                    context.read<TournamentsBloc>().add(CreateTournament(tournament));
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentAdminCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onCancel;
  static final _dateFmt = DateFormat('EEE, MMM d, yyyy · HH:mm');

  const _TournamentAdminCard({required this.tournament, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isCancelled = tournament.status == TournamentStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${tournament.venueName} · ${_dateFmt.format(tournament.startTime)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${tournament.participantIds.length}/${tournament.maxParticipants} joined · EGP ${tournament.entryFee.toInt()} entry'
                  '${isCancelled ? ' · Cancelled' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCancelled ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isCancelled)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
