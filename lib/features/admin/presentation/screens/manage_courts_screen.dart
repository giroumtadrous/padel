import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/admin/data/services/admin_service.dart';
import 'package:padel/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:padel/features/admin/presentation/bloc/admin_event.dart';
import 'package:padel/features/venues/data/models/court_model.dart';
import 'package:padel/features/venues/data/services/venue_service.dart';

class ManageCourtsScreen extends StatefulWidget {
  final String venueId;
  const ManageCourtsScreen({super.key, required this.venueId});

  @override
  State<ManageCourtsScreen> createState() => _ManageCourtsScreenState();
}

class _ManageCourtsScreenState extends State<ManageCourtsScreen> {
  List<CourtModel> _courts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    setState(() => _loading = true);
    final courts = await context.read<AdminService>().getAdminCourts(widget.venueId);
    setState(() {
      _courts = courts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courts'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(
            onPressed: () => _showAddCourtSheet(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingSpinner()
          : _courts.isEmpty
              ? const Center(child: Text('No courts yet. Add one!'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CourtAdminCard(
                    court: _courts[i],
                    venueId: widget.venueId,
                    onToggle: (isActive) {
                      context.read<AdminBloc>().add(ToggleCourtActive(
                            venueId: widget.venueId,
                            courtId: _courts[i].id,
                            isActive: isActive,
                          ));
                      _loadCourts();
                    },
                    onEdit: () => _showEditCourtSheet(_courts[i]),
                  ),
                ),
    );
  }

  void _showAddCourtSheet() {
    _showCourtFormSheet(null);
  }

  void _showEditCourtSheet(CourtModel court) {
    _showCourtFormSheet(court);
  }

  void _showCourtFormSheet(CourtModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final peakCtrl = TextEditingController(text: existing?.peakHourPrice.toString() ?? '150');
    final offPeakCtrl = TextEditingController(text: existing?.offPeakPrice.toString() ?? '90');
    String courtType = existing?.courtType ?? 'indoor';
    String surface = existing?.surface ?? 'glass';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add Court' : 'Edit Court',
                  style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Court Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: peakCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Peak Price (EGP)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: offPeakCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Off-Peak Price (EGP)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: courtType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      dropdownColor: AppColors.card,
                      items: ['indoor', 'outdoor']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => courtType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: surface,
                      decoration: const InputDecoration(labelText: 'Surface'),
                      dropdownColor: AppColors.card,
                      items: ['glass', 'turf']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => surface = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                label: existing == null ? 'Add Court' : 'Save Changes',
                onPressed: () async {
                  final court = CourtModel(
                    id: existing?.id ?? '',
                    venueId: widget.venueId,
                    name: nameCtrl.text,
                    courtType: courtType,
                    surface: surface,
                    peakHourPrice: double.tryParse(peakCtrl.text) ?? 150,
                    offPeakPrice: double.tryParse(offPeakCtrl.text) ?? 90,
                  );
                  if (existing == null) {
                    await context.read<VenueService>().addCourt(widget.venueId, court);
                  } else {
                    context.read<AdminBloc>().add(UpdateCourt(venueId: widget.venueId, court: court));
                  }
                  Navigator.pop(ctx);
                  _loadCourts();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourtAdminCard extends StatelessWidget {
  final CourtModel court;
  final String venueId;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _CourtAdminCard({
    required this.court,
    required this.venueId,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: court.isActive ? AppColors.divider : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: court.isActive
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sports_tennis_rounded,
              color: court.isActive ? AppColors.primary : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(court.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${court.courtType} · ${court.surface} · Peak: EGP ${court.peakHourPrice.toInt()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
          ),
          Switch(
            value: court.isActive,
            onChanged: onToggle,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
