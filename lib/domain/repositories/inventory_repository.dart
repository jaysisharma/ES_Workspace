import '../entities/inventory_entity.dart';

abstract class InventoryRepository {
  Future<List<InventoryItemEntity>> getAllInventoryItems();
  Future<void> addInventoryItem(InventoryItemEntity item);
  Future<void> updateInventoryItem(InventoryItemEntity item);
  Future<void> deleteInventoryItem(String id);
  Future<void> adjustStock(String id, int delta);
}
