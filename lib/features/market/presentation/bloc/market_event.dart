import 'package:equatable/equatable.dart';
import 'package:padel/features/market/data/models/market_item_model.dart';

abstract class MarketEvent extends Equatable {
  const MarketEvent();
  @override
  List<Object?> get props => [];
}

class LoadMarketItems extends MarketEvent {
  const LoadMarketItems();
}

class BuyMarketItem extends MarketEvent {
  final String itemId;
  final String buyerId;
  const BuyMarketItem({required this.itemId, required this.buyerId});
  @override
  List<Object?> get props => [itemId, buyerId];
}

class CreateMarketItem extends MarketEvent {
  final MarketItemModel item;
  const CreateMarketItem(this.item);
  @override
  List<Object?> get props => [item.name, item.sellerId];
}

class RemoveMarketItem extends MarketEvent {
  final String itemId;
  final String sellerId;
  const RemoveMarketItem({required this.itemId, required this.sellerId});
  @override
  List<Object?> get props => [itemId];
}
