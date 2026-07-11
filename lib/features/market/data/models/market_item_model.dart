import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:padel/core/constants/app_constants.dart';

enum MarketItemStatus { active, sold, removed }

MarketItemStatus marketItemStatusFromString(String s) {
  switch (s) {
    case AppConstants.marketItemSold:
      return MarketItemStatus.sold;
    case AppConstants.marketItemRemoved:
      return MarketItemStatus.removed;
    default:
      return MarketItemStatus.active;
  }
}

String marketItemStatusToString(MarketItemStatus s) {
  switch (s) {
    case MarketItemStatus.sold:
      return AppConstants.marketItemSold;
    case MarketItemStatus.removed:
      return AppConstants.marketItemRemoved;
    case MarketItemStatus.active:
      return AppConstants.marketItemActive;
  }
}

class MarketItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final String sellerId;
  final String sellerName;
  final MarketItemStatus status;
  final DateTime createdAt;

  const MarketItemModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl,
    this.category = 'other',
    required this.sellerId,
    required this.sellerName,
    this.status = MarketItemStatus.active,
    required this.createdAt,
  });

  factory MarketItemModel.fromJson(Map<String, dynamic> json) => MarketItemModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['imageUrl'] as String?,
        category: json['category'] as String? ?? 'other',
        sellerId: json['sellerId'] as String? ?? '',
        sellerName: json['sellerName'] as String? ?? '',
        status: marketItemStatusFromString(json['status'] as String? ?? AppConstants.marketItemActive),
        createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'status': marketItemStatusToString(status),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
