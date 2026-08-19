import '../entities/order_entity.dart';
import '../entities/order_item_entity.dart';
import '../entities/expense_entity.dart';

abstract class OrderRepository {
  Future<void> createOrder(OrderEntity order);
  Future<void> updateOrder(OrderEntity order);
  Future<OrderEntity?> getOrderById(String id);
  Future<List<OrderEntity>> getAllOrders();
  Future<Map<String, dynamic>> getOrdersPaginated(int limit, {dynamic lastDoc});
  Future<void> deleteOrder(String id);
  Future<void> deleteOrders(List<String> ids);
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
