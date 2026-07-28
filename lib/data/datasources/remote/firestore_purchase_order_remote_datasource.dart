import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/purchase_order_entity.dart';

abstract class PurchaseOrderRemoteDataSource {
  Future<void> create(PurchaseOrderEntity po);
  Future<void> update(PurchaseOrderEntity po);
  Future<void> delete(String id);
  Future<PurchaseOrderEntity?> getById(String id);
  Future<List<PurchaseOrderEntity>> getAll();
  Stream<List<PurchaseOrderEntity>> getAllStream();
}

class FirestorePurchaseOrderRemoteDataSource
    implements PurchaseOrderRemoteDataSource {
  final _collection = FirebaseFirestore.instance.collection('purchase_orders');

  @override
  Future<void> create(PurchaseOrderEntity po) async {
    await _collection.doc(po.id).set(po.toJson());
  }

  @override
  Future<void> update(PurchaseOrderEntity po) async {
    await _collection.doc(po.id).update(po.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }

  @override
  Future<PurchaseOrderEntity?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return PurchaseOrderEntity.fromJson(doc.data()!);
  }

  @override
  Future<List<PurchaseOrderEntity>> getAll() async {
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PurchaseOrderEntity.fromJson(doc.data()))
        .toList();
  }

  @override
  Stream<List<PurchaseOrderEntity>> getAllStream() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => PurchaseOrderEntity.fromJson(doc.data()))
          .toList();
    });
  }
}
