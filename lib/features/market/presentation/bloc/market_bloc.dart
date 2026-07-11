import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/features/market/data/services/market_service.dart';
import 'market_event.dart';
import 'market_state.dart';

class MarketBloc extends Bloc<MarketEvent, MarketState> {
  final MarketService _marketService;

  MarketBloc({required MarketService marketService})
      : _marketService = marketService,
        super(const MarketInitial()) {
    on<LoadMarketItems>(_onLoad);
    on<BuyMarketItem>(_onBuy);
    on<CreateMarketItem>(_onCreate);
    on<RemoveMarketItem>(_onRemove);
  }

  Future<void> _onLoad(LoadMarketItems event, Emitter<MarketState> emit) async {
    emit(const MarketLoading());
    await emit.onEach(
      _marketService.getMarketItemsStream(),
      onData: (items) => emit(MarketLoaded(items)),
      onError: (e, _) => emit(MarketError(e.toString())),
    );
  }

  Future<void> _onBuy(BuyMarketItem event, Emitter<MarketState> emit) async {
    final current = state;
    emit(const MarketActionInProgress());
    try {
      await _marketService.buyItem(event.itemId, event.buyerId);
      emit(MarketItemBought(event.itemId));
      if (current is MarketLoaded) emit(current);
    } catch (e) {
      emit(MarketError(e.toString()));
      if (current is MarketLoaded) emit(current);
    }
  }

  Future<void> _onCreate(CreateMarketItem event, Emitter<MarketState> emit) async {
    emit(const MarketActionInProgress());
    try {
      final id = await _marketService.createMarketItem(event.item);
      emit(MarketItemCreated(id));
    } catch (e) {
      emit(MarketError(e.toString()));
    }
  }

  Future<void> _onRemove(RemoveMarketItem event, Emitter<MarketState> emit) async {
    try {
      await _marketService.removeMarketItem(event.itemId, event.sellerId);
    } catch (e) {
      emit(MarketError(e.toString()));
    }
  }
}
