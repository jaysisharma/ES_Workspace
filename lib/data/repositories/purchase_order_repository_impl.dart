import 'package:order_app/domain/entities/purchase_order_entity.dart';
import 'package:order_app/domain/repositories/purchase_order_repository.dart';
import '../datasources/remote/firestore_purchase_order_remote_datasource.dart';

class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  final PurchaseOrderRemoteDataSource remoteDataSource;

  PurchaseOrderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> createPurchaseOrder(PurchaseOrderEntity po) {
    return remoteDataSource.create(po);
  }

  @override
  Future<void> updatePurchaseOrder(PurchaseOrderEntity po) {
    return remoteDataSource.update(po);
  }

  @override
  Future<void> deletePurchaseOrder(String id) {
    return remoteDataSource.delete(id);
  }

  @override
  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id) {
    return remoteDataSource.getById(id);
  }

  @override
  Future<List<PurchaseOrderEntity>> getPurchaseOrders() {
    return remoteDataSource.getAll();
  }

  @override
  Stream<List<PurchaseOrderEntity>> getPurchaseOrdersStream() {
    return remoteDataSource.getAllStream();
  }
}
