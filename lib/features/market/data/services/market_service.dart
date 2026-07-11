import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/features/auth/data/models/user_model.dart';
import 'package:padel/features/market/data/models/market_item_model.dart';

class MarketService {
  final FirebaseFirestore _db;

  MarketService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<MarketItemModel>> getMarketItemsStream() {
    return _db
        .collection(AppConstants.marketItemsCollection)
        .where('status', isEqualTo: AppConstants.marketItemActive)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MarketItemModel.fromJson(d.data())).toList());
  }

  Future<String> createMarketItem(MarketItemModel item) async {
    final ref = _db.collection(AppConstants.marketItemsCollection).doc();
    final withId = MarketItemModel(
      id: ref.id,
      name: item.name,
      description: item.description,
      price: item.price,
      imageUrl: item.imageUrl,
      category: item.category,
      sellerId: item.sellerId,
      sellerName: item.sellerName,
      createdAt: DateTime.now(),
    );
    await ref.set(withId.toJson());
    return ref.id;
  }

  Future<List<MarketItemModel>> getSellerItems(String sellerId) async {
    final snap = await _db
        .collection(AppConstants.marketItemsCollection)
        .where('sellerId', isEqualTo: sellerId)
        .get();
    return snap.docs.map((d) => MarketItemModel.fromJson(d.data())).toList();
  }

  Future<void> removeMarketItem(String itemId, String sellerId) async {
    final ref = _db.collection(AppConstants.marketItemsCollection).doc(itemId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Item not found');

    final item = MarketItemModel.fromJson(snap.data()!);
    if (item.sellerId != sellerId) throw Exception('Only the seller can remove this listing');

    await ref.update({'status': AppConstants.marketItemRemoved});
  }

  /// Buys an item and deducts its price from the buyer's wallet in the same
  /// transaction, so a buyer is never charged without the item actually
  /// being reserved for them (or vice versa).
  Future<void> buyItem(String itemId, String buyerId) async {
    final itemRef = _db.collection(AppConstants.marketItemsCollection).doc(itemId);
    final buyerRef = _db.collection(AppConstants.usersCollection).doc(buyerId);

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) throw Exception('Item not found');
      final item = MarketItemModel.fromJson(itemSnap.data()!);

      if (item.status != MarketItemStatus.active) throw Exception('This item is no longer available');
      if (item.sellerId == buyerId) throw Exception('You can\'t buy your own listing');

      final buyerSnap = await tx.get(buyerRef);
      if (!buyerSnap.exists) throw Exception('User profile not found');
      final buyer = UserModel.fromJson(buyerSnap.data()!);

      if (buyer.walletBalance < item.price) throw Exception('Insufficient wallet balance');

      tx.update(itemRef, {'status': AppConstants.marketItemSold});
      tx.update(buyerRef, {'walletBalance': FieldValue.increment(-item.price)});
    });
  }
}
