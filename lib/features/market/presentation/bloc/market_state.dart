import 'package:equatable/equatable.dart';
import 'package:padel/features/market/data/models/market_item_model.dart';

abstract class MarketState extends Equatable {
  const MarketState();
  @override
  List<Object?> get props => [];
}

class MarketInitial extends MarketState {
  const MarketInitial();
}

class MarketLoading extends MarketState {
  const MarketLoading();
}

class MarketLoaded extends MarketState {
  final List<MarketItemModel> items;
  const MarketLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class MarketActionInProgress extends MarketState {
  const MarketActionInProgress();
}

class MarketItemBought extends MarketState {
  final String itemId;
  const MarketItemBought(this.itemId);
  @override
  List<Object?> get props => [itemId];
}

class MarketItemCreated extends MarketState {
  final String itemId;
  const MarketItemCreated(this.itemId);
  @override
  List<Object?> get props => [itemId];
}

class MarketError extends MarketState {
  final String message;
  const MarketError(this.message);
  @override
  List<Object?> get props => [message];
}
