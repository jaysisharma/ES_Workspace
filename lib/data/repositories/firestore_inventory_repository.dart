import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../core/errors/failures.dart';

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
    return InventoryItemEntity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      totalQuantity: (data['totalQuantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (data['availableQuantity'] as num?)?.toInt() ?? 0,
      rentalRatePerDay: (data['rentalRatePerDay'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'Available',
      location: data['location'] as String? ?? 'Warehouse',
      description: data['description'] as String? ?? '',
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
        'name': item.name,
        'sku': item.sku,
        'category': item.category,
        'totalQuantity': item.totalQuantity,
        'availableQuantity': item.availableQuantity,
        'rentalRatePerDay': item.rentalRatePerDay,
        'status': item.status,
        'location': item.location,
        'description': item.description,
        'createdAt': item.createdAt != null
            ? Timestamp.fromDate(item.createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
