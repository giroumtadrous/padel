import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/widgets/app_error_view.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/market/data/models/market_item_model.dart';
import 'package:padel/features/market/presentation/bloc/market_bloc.dart';
import 'package:padel/features/market/presentation/bloc/market_event.dart';
import 'package:padel/features/market/presentation/bloc/market_state.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MarketBloc>().add(const LoadMarketItems());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: BlocListener<MarketBloc, MarketState>(
        listener: (context, state) {
          if (state is MarketError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
          if (state is MarketItemBought) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase successful!')),
            );
          }
        },
        child: BlocBuilder<MarketBloc, MarketState>(
          builder: (context, state) {
            if (state is MarketLoading) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            if (state is MarketError) {
              return AppErrorView(
                message: state.message,
                onRetry: () => context.read<MarketBloc>().add(const LoadMarketItems()),
              );
            }
            if (state is MarketLoaded) {
              if (state.items.isEmpty) {
                return const AppEmptyView(
                  title: 'No items for sale',
                  subtitle: 'Padel gear listed by the community will show up here.',
                  icon: Icons.storefront_outlined,
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: state.items.length,
                itemBuilder: (_, i) => _MarketItemCard(item: state.items[i]),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _MarketItemCard extends StatelessWidget {
  final MarketItemModel item;
  const _MarketItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : '';
    final isOwnListing = item.sellerId == userId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.cardElevated,
                    child: const Icon(Icons.sports_tennis_rounded, color: AppColors.textHint, size: 36),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'EGP ${item.price.toInt()}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: isOwnListing
                      ? const Text('Your listing', style: TextStyle(color: AppColors.textHint, fontSize: 12))
                      : GestureDetector(
                          onTap: () => _confirmBuy(context, userId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Buy Now',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBuy(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buy Item'),
        content: Text('Buy "${item.name}" for EGP ${item.price.toInt()}? This will be deducted from your wallet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MarketBloc>().add(BuyMarketItem(itemId: item.id, buyerId: userId));
            },
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }
}
