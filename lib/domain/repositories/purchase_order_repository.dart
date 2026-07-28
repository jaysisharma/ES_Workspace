import '../entities/purchase_order_entity.dart';

abstract class PurchaseOrderRepository {
  Future<void> createPurchaseOrder(PurchaseOrderEntity po);
  Future<void> updatePurchaseOrder(PurchaseOrderEntity po);
  Future<void> deletePurchaseOrder(String id);
  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id);
  Future<List<PurchaseOrderEntity>> getPurchaseOrders();
  Stream<List<PurchaseOrderEntity>> getPurchaseOrdersStream();
}
