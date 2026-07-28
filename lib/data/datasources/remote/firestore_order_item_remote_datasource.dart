import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/errors/failures.dart';
import '../../models/order_item_model.dart';
import '../../../domain/entities/order_item_entity.dart';

abstract class OrderItemRemoteDataSource {
  Future<void> addItem(OrderItemEntity item);
  Future<void> updateItem(OrderItemEntity item);
  Future<void> deleteItem(String itemId);
  Future<List<OrderItemEntity>> getItemsByOrderId(String orderId);
  Future<List<OrderItemEntity>> getAllItems();
  Stream<List<OrderItemEntity>> getAllItemsStream();
}

class FirestoreOrderItemRemoteDataSource implements OrderItemRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreOrderItemRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addItem(OrderItemEntity item) async {
    try {
      final itemModel = OrderItemModel.fromEntity(item);
      await _firestore
          .collection('order_items')
          .doc(itemModel.id)
          .set(itemModel.toJson());
    } catch (e) {
      throw ServerException('Failed to add order item: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      await _firestore.collection('order_items').doc(itemId).delete();
    } catch (e) {
      throw ServerException('Failed to delete order item: ${e.toString()}');
    }
  }

  @override
  Future<void> updateItem(OrderItemEntity item) async {
    try {
      final itemModel = OrderItemModel.fromEntity(item);
      await _firestore
          .collection('order_items')
          .doc(itemModel.id)
          .update(itemModel.toJson());
    } catch (e) {
      throw ServerException('Failed to update order item: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderItemEntity>> getItemsByOrderId(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('order_items')
          .where('orderId', isEqualTo: orderId)
          .get();

      return querySnapshot.docs.map((doc) {
        return OrderItemModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch order items: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderItemEntity>> getAllItems() async {
    try {
      final querySnapshot = await _firestore.collection('order_items').get();

      return querySnapshot.docs.map((doc) {
        return OrderItemModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch all order items: ${e.toString()}');
    }
  }

  @override
  Stream<List<OrderItemEntity>> getAllItemsStream() {
    return _firestore.collection('order_items').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return OrderItemModel.fromJson(doc.data());
      }).toList();
    });
  }
}
