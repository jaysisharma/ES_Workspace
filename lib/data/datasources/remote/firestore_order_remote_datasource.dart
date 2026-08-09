import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:order_app/core/errors/failures.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import '../../models/order_model.dart';
import '../../models/expense_model.dart';

abstract class OrderRemoteDataSource {
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrder(OrderEntity order);
  Future<OrderEntity?> getOrderById(String id);
  Future<List<OrderEntity>> getAllOrders();
  Future<Map<String, dynamic>> getOrdersPaginated(int limit, {DocumentSnapshot? lastDoc});
  Future<void> deleteOrder(String id);
  Future<void> finalizeRevenue(
    OrderEntity order,
    List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue,
  );
  Future<void> finalizeExpenses(
    OrderEntity order,
    List<ExpenseEntity> expenses,
    List<OrderItemEntity> items,
  );
  Future<List<ExpenseEntity>> getExpenses(String orderId);
  Future<List<ExpenseEntity>> getAdditionalRevenue(String orderId);
  Stream<List<OrderEntity>> getOrdersStream();
  Stream<List<ExpenseEntity>> getAllAdditionalRevenueStream();
  Stream<List<ExpenseEntity>> getAllExpensesStream();
}

class FirestoreOrderRemoteDataSource implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreOrderRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createOrder(OrderEntity order) async {
    try {
      final orderModel = OrderModel.fromEntity(order);
      await _firestore
          .collection('orders')
          .doc(orderModel.id)
          .set(orderModel.toJson());
    } catch (e) {
      throw ServerException('Failed to create order: ${e.toString()}');
    }
  }

  @override
  Future<void> updateOrder(OrderEntity order) async {
    try {
      final orderModel = OrderModel.fromEntity(order);
      await _firestore
          .collection('orders')
          .doc(orderModel.id)
          .update(orderModel.toJson());
    } catch (e) {
      throw ServerException('Failed to update order: ${e.toString()}');
    }
  }

  @override
  Future<OrderEntity?> getOrderById(String id) async {
    try {
      final docSnapshot = await _firestore.collection('orders').doc(id).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return OrderModel.fromJson(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      throw ServerException('Failed to fetch order: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderEntity>> getAllOrders() async {
    try {
      final querySnapshot = await _firestore.collection('orders').get();
      return querySnapshot.docs.map((doc) {
        return OrderModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch all orders: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getOrdersPaginated(int limit, {DocumentSnapshot? lastDoc}) async {
    try {
      Query query = _firestore.collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final querySnapshot = await query.get();
      final orders = querySnapshot.docs.map((doc) {
        return OrderModel.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      final lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;

      return {
        'orders': orders,
        'lastDoc': lastDocument,
        'hasMore': orders.length == limit,
      };
    } catch (e) {
      throw ServerException('Failed to fetch paginated orders: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    try {
      await _firestore.collection('orders').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete order: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizeRevenue(
    OrderEntity order,
    List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue,
  ) async {
    try {
      debugPrint('=== [FIRESTORE REMOTE DATASOURCE FINALIZE REVENUE] ===');
      debugPrint('Order ID: ${order.id}');
      debugPrint('Updating orders/${order.id}:');
      debugPrint('  description: ${order.description}');
      debugPrint('  totalAmount: ${order.totalAmount}');
      debugPrint('  vatRate: ${order.vatRate}');
      debugPrint('  advanceReceived: ${order.advanceReceived}');
      debugPrint('  advanceReferenceNo: ${order.advanceReferenceNo}');
      debugPrint('  managementCharge: ${order.managementCharge}');
      debugPrint('  isMgtChargePercent: ${order.isMgtChargePercent}');
      debugPrint('  discount: ${order.discount}');
      debugPrint('  isDiscountPercent: ${order.isDiscountPercent}');

      final batch = _firestore.batch();

      // Update order - include description, notes, totalAmount, vatRate, logs, and updatedAt
      final orderRef = _firestore.collection('orders').doc(order.id);
      batch.update(orderRef, {
        'description': order.description,
        'notes': order.notes,
        'totalAmount': order.totalAmount,
        'vatRate': order.vatRate,
        'advanceReceived': order.advanceReceived,
        'advanceReferenceNo': order.advanceReferenceNo,
        'managementCharge': order.managementCharge,
        'isMgtChargePercent': order.isMgtChargePercent,
        'discount': order.discount,
        'isDiscountPercent': order.isDiscountPercent,
        'logs': order.logs
            .map(
              (log) => {
                'timestamp': log.timestamp.toIso8601String(),
                'message': log.message,
              },
            )
            .toList(),
        'updatedAt': order.updatedAt.toIso8601String(),
      });

      // Clear old additional revenues to avoid duplicates/orphans
      final existingRevs = await _firestore
          .collection('additional_revenue')
          .where('orderId', isEqualTo: order.id)
          .get();
      for (final doc in existingRevs.docs) {
        batch.delete(doc.reference);
      }

      // Save additional revenues
      for (final rev in additionalRevenue) {
        final revModel = ExpenseModel.fromEntity(rev);
        final revRef = _firestore.collection('additional_revenue').doc(rev.id);
        batch.set(revRef, revModel.toJson());
      }

      // Update items - rate, quantity, days, billingType, and amount
      for (final item in items) {
        debugPrint('  Updating order_items/${item.id}: rate=${item.rate}, quantity=${item.quantity}, days=${item.days}, amount=${item.amount}, billingType=${item.billingType}');
        final itemRef = _firestore.collection('order_items').doc(item.id);
        batch.update(itemRef, {
          'rate': item.rate,
          'quantity': item.quantity,
          'days': item.days,
          'billingType': item.billingType,
          'amount': item.amount,
        });
      }

      await batch.commit();
      debugPrint('Batch commit successful for revenue finalization!');
      debugPrint('==================================================');
    } catch (e) {
      throw ServerException('Failed to finalize revenue: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizeExpenses(
    OrderEntity order,
    List<ExpenseEntity> expenses,
    List<OrderItemEntity> items,
  ) async {
    try {
      final batch = _firestore.batch();

      // Update order - include description, notes, totalExpenses, logs, and updatedAt
      final orderRef = _firestore.collection('orders').doc(order.id);
      batch.update(orderRef, {
        'description': order.description,
        'notes': order.notes,
        'totalExpenses': order.totalExpenses,
        'logs': order.logs
            .map(
              (log) => {
                'timestamp': log.timestamp.toIso8601String(),
                'message': log.message,
              },
            )
            .toList(),
        'updatedAt': order.updatedAt.toIso8601String(),
      });

      // Update manual expenses
      for (final expense in expenses) {
        final expenseModel = ExpenseModel.fromEntity(expense);
        final expenseRef = _firestore
            .collection('expenses')
            .doc(expenseModel.id);
        batch.set(expenseRef, expenseModel.toJson());
      }

      // Update item-based vendor costs - only vendorRate and vendorAmount
      for (final item in items) {
        final itemRef = _firestore.collection('order_items').doc(item.id);
        batch.update(itemRef, {
          'vendorRate': item.vendorRate,
          'vendorAmount': item.vendorAmount,
        });
      }

      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to finalize expenses: ${e.toString()}');
    }
  }

  @override
  Future<List<ExpenseEntity>> getExpenses(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('expenses')
          .where('orderId', isEqualTo: orderId)
          .get();

      return querySnapshot.docs.map((doc) {
        return ExpenseModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch expenses: ${e.toString()}');
    }
  }

  @override
  Future<List<ExpenseEntity>> getAdditionalRevenue(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('additional_revenue')
          .where('orderId', isEqualTo: orderId)
          .get();

      return querySnapshot.docs.map((doc) {
        return ExpenseModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException(
        'Failed to fetch additional revenue: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<OrderEntity>> getOrdersStream() {
    return _firestore.collection('orders').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data()))
          .toList();
    });
  }

  @override
  Stream<List<ExpenseEntity>> getAllAdditionalRevenueStream() {
    return _firestore
        .collection('additional_revenue')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExpenseModel.fromJson(doc.data()))
              .toList();
        });
  }

  @override
  Stream<List<ExpenseEntity>> getAllExpensesStream() {
    return _firestore.collection('expenses').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ExpenseModel.fromJson(doc.data()))
          .toList();
    });
  }
}
