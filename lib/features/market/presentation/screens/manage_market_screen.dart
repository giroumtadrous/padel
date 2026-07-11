import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/core/widgets/app_loading.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/market/data/models/market_item_model.dart';
import 'package:padel/features/market/data/services/market_service.dart';
import 'package:padel/features/market/presentation/bloc/market_bloc.dart';
import 'package:padel/features/market/presentation/bloc/market_event.dart';

class ManageMarketScreen extends StatefulWidget {
  const ManageMarketScreen({super.key});

  @override
  State<ManageMarketScreen> createState() => _ManageMarketScreenState();
}

class _ManageMarketScreenState extends State<ManageMarketScreen> {
  List<MarketItemModel> _items = [];
  bool _loading = true;

  String get _sellerId {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.uid : '';
  }

  String get _sellerName {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.user.displayName : '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await context.read<MarketService>().getSellerItems(_sellerId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Market'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(onPressed: _showCreateSheet, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const AppLoadingSpinner()
          : _items.isEmpty
              ? const Center(child: Text('No listings yet. Add one!'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _MarketAdminCard(
                    item: _items[i],
                    onRemove: () async {
                      context.read<MarketBloc>().add(RemoveMarketItem(
                            itemId: _items[i].id,
                            sellerId: _sellerId,
                          ));
                      await _load();
                    },
                  ),
                ),
    );
  }

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '100');
    final imageCtrl = TextEditingController();
    String category = 'racket';

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
                Text('Add Listing', style: Theme.of(ctx).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Price (EGP)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        dropdownColor: AppColors.card,
                        items: ['racket', 'balls', 'shoes', 'apparel', 'other']
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) => setSheetState(() => category = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: 'Image URL (optional)'),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Add Listing',
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final item = MarketItemModel(
                      id: '',
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text) ?? 0,
                      imageUrl: imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                      category: category,
                      sellerId: _sellerId,
                      sellerName: _sellerName,
                      createdAt: DateTime.now(),
                    );
                    context.read<MarketBloc>().add(CreateMarketItem(item));
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

class _MarketAdminCard extends StatelessWidget {
  final MarketItemModel item;
  final VoidCallback onRemove;

  const _MarketAdminCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isRemoved = item.status == MarketItemStatus.removed;
    final isSold = item.status == MarketItemStatus.sold;
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
                Text(item.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'EGP ${item.price.toInt()} · ${item.category}'
                  '${isSold ? ' · Sold' : ''}${isRemoved ? ' · Removed' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRemoved ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isRemoved && !isSold)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
