import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/inventory_entity.dart';
import 'package:order_app/domain/repositories/inventory_repository.dart';
import 'package:order_app/core/errors/failures.dart';

class FirestoreInventoryRepository implements InventoryRepository {
  final FirebaseFirestore _firestore;

  FirestoreInventoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<InventoryItemEntity>> getAllInventoryItems() async {
    try {
      final snapshot = await _firestore
          .collection('inventory')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to get inventory items: ${e.toString()}');
    }
  }

  @override
  Future<void> addInventoryItem(InventoryItemEntity item) async {
    try {
      final docRef = _firestore.collection('inventory').doc();
      await docRef.set(_toJson(item).toMap(docRef.id));
    } catch (e) {
      throw ServerException('Failed to add inventory item: ${e.toString()}');
    }
  }

  @override
  Future<void> updateInventoryItem(InventoryItemEntity item) async {
    try {
      await _firestore
          .collection('inventory')
          .doc(item.id)
          .update(_toJson(item).toMap(item.id));
    } catch (e) {
      throw ServerException('Failed to update inventory item: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteInventoryItem(String id) async {
    try {
      await _firestore.collection('inventory').doc(id).delete();
    } catch (e) {
      throw ServerException('Failed to delete inventory item: ${e.toString()}');
    }
  }

  @override
  Future<void> adjustStock(String id, int delta) async {
    try {
      final docRef = _firestore.collection('inventory').doc(id);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final data = snapshot.data()!;
        final currentAvailable = (data['availableQuantity'] as num?)?.toInt() ?? 0;
        final currentTotal = (data['totalQuantity'] as num?)?.toInt() ?? 0;

        int newAvailable = currentAvailable + delta;
        int newTotal = currentTotal;
        if (delta > 0 && newAvailable > newTotal) {
          newTotal = newAvailable;
        }
        if (newAvailable < 0) newAvailable = 0;

        String status = 'Available';
        if (newAvailable <= 0) {
          status = 'Out of Stock';
        } else if (newAvailable <= 3) {
          status = 'Low Stock';
        }

        transaction.update(docRef, {
          'availableQuantity': newAvailable,
          'totalQuantity': newTotal,
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw ServerException('Failed to adjust inventory stock: ${e.toString()}');
    }
  }

  InventoryItemEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawItemNo = data['itemNo'] as String? ?? data['sku'] as String? ?? '';
    final rawSpec = data['specification'] as String? ?? data['description'] as String? ?? '';
    final rawQty = (data['quantity'] as num?)?.toInt() ?? (data['totalQuantity'] as num?)?.toInt() ?? 0;
    final rawAvail = (data['availableQuantity'] as num?)?.toInt() ?? rawQty;
    final rawRate = (data['rate'] as num?)?.toDouble() ?? (data['rentalRatePerDay'] as num?)?.toDouble() ?? 0.0;

    return InventoryItemEntity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      itemNo: rawItemNo,
      category: data['category'] as String? ?? 'General',
      specification: rawSpec,
      quantity: rawQty,
      availableQuantity: rawAvail,
      rate: rawRate,
      status: data['status'] as String? ?? 'Available',
      location: data['location'] as String? ?? 'Warehouse',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  _InventoryJson _toJson(InventoryItemEntity item) => _InventoryJson(item);
}

class _InventoryJson {
  final InventoryItemEntity item;
  const _InventoryJson(this.item);

  Map<String, dynamic> toMap(String id) => {
        'id': id,
        'itemNo': item.itemNo,
        'sku': item.itemNo, // backward compatibility
        'name': item.name,
        'category': item.category,
        'specification': item.specification,
        'description': item.specification, // backward compatibility
        'quantity': item.quantity,
        'totalQuantity': item.quantity, // backward compatibility
        'availableQuantity': item.availableQuantity,
        'rate': item.rate,
        'rentalRatePerDay': item.rate, // backward compatibility
        'total': item.total,
        'status': item.status,
        'location': item.location,
        'createdAt': item.createdAt != null
            ? Timestamp.fromDate(item.createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
