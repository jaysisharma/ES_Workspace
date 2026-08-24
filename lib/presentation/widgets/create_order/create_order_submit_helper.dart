import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/domain/entities/client_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/client_provider.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'item_row_model.dart';

class CreateOrderSubmitHelper {
  static Future<void> submitOrder({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDraft,
    required bool isEditMode,
    required OrderEntity? existingOrder,
    required TextEditingController orderIdController,
    required TextEditingController eventNameController,
    required TextEditingController venueController,
    required TextEditingController contactPersonController,
    required TextEditingController contactNumberController,
    required TextEditingController descriptionController,
    required DateTime eventDate,
    required DateTime? eventEndDate,
    required DateTime setupDate,
    required DateTime? setupEndDate,
    required String? selectedCategory,
    required String orderType,
    required double vatRate,
    required List<ItemRow> items,
    required ValueChanged<bool> onSavingStateChanged,
  }) async {
    if (eventNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }
    if (venueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a venue')),
      );
      return;
    }
    if (contactPersonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a contact person')),
      );
      return;
    }
    if (contactNumberController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact number must be exactly 10 digits'),
        ),
      );
      return;
    }

    if (setupDate.isAfter(eventDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup date cannot be after event date')),
      );
      return;
    }

    bool hasValidItem = items.any(
      (item) => item.nameController.text.isNotEmpty,
    );
    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item with a name'),
        ),
      );
      return;
    }

    onSavingStateChanged(true);

    try {
      final currentOrder = existingOrder;
      final now = DateTime.now();
      final String finalOrderId = isEditMode
          ? existingOrder!.id
          : (orderIdController.text.trim().isEmpty
              ? 'ORD-${DateTime.now().millisecondsSinceEpoch}'
              : orderIdController.text.trim());

      final contactName = contactPersonController.text.trim();
      final contactPhone = contactNumberController.text.trim();
      final eventName = eventNameController.text.trim();

      final clients = ref.read(clientNotifierProvider).clients;
      final existingClientIndex = clients.indexWhere(
        (c) =>
            c.name.toLowerCase() == contactName.toLowerCase() &&
            c.phone == contactPhone,
      );

      if (existingClientIndex != -1) {
        final existing = clients[existingClientIndex];
        await ref.read(clientNotifierProvider.notifier).updateClient(
              existing.copyWith(
                name: contactName,
                contactPerson: contactName,
                notes:
                    '${existing.notes}\nAutomatically added from Order $finalOrderId'
                        .trim(),
              ),
            );
      } else {
        await ref.read(clientNotifierProvider.notifier).addClient(
              ClientEntity(
                id: '',
                name: contactName,
                contactPerson: contactName,
                phone: contactPhone,
                email: '',
                notes: 'Automatically added from Order $finalOrderId',
              ),
            );
      }

      final order = OrderEntity(
        id: finalOrderId,
        eventName: eventName,
        eventDate: eventDate,
        eventEndDate: eventEndDate,
        setupDate: setupDate,
        setupEndDate: setupEndDate,
        venue: venueController.text.trim(),
        contactPerson: contactName,
        contactNumber: contactPhone,
        notes: currentOrder?.notes ?? '',
        status: isEditMode
            ? (currentOrder!.status == OrderStatus.completed
                ? OrderStatus.confirmed
                : currentOrder.status)
            : (isDraft ? OrderStatus.draft : OrderStatus.confirmed),
        assignedStaffIds: isEditMode ? (currentOrder!.assignedStaffIds) : [],
        totalAmount: currentOrder?.totalAmount ?? 0.0,
        totalExpenses: currentOrder?.totalExpenses ?? 0.0,
        createdAt: currentOrder?.createdAt ?? now,
        updatedAt: now,
        category: selectedCategory ?? '',
        client: contactName,
        description: descriptionController.text.trim(),
        vatRate: vatRate,
        orderType: orderType,
      );

      if (isEditMode) {
        await ref.read(orderNotifierProvider.notifier).updateOrder(order);
      } else {
        await ref.read(orderNotifierProvider.notifier).create(order);
      }

      final Map<String, OrderItemEntity> existingStates = {};
      if (isEditMode) {
        final currentItems = ref.read(orderItemNotifierProvider).items;
        for (final item in currentItems) {
          final key = '${item.itemName.trim()}_${item.specification.trim()}';
          existingStates[key] = item;
        }
        await ref
            .read(orderItemNotifierProvider.notifier)
            .deleteItemsForOrder(finalOrderId);
      }
      final List<Future<void>> itemFutures = [];
      for (var itemRow in items) {
        if (itemRow.nameController.text.isNotEmpty) {
          final itemName = itemRow.nameController.text.trim();
          final spec = itemRow.specController.text.trim();
          final key = '${itemName}_$spec';
          final existing = existingStates[key];

          final item = OrderItemEntity(
            id: const Uuid().v4(),
            orderId: finalOrderId,
            itemName: itemName,
            specification: spec,
            quantity: int.tryParse(itemRow.qtyController.text) ?? 1,
            unit: itemRow.unitController.text,
            days: int.tryParse(itemRow.daysController.text) ?? 1,
            vendor: itemRow.vendorController.text,
            billingType: itemRow.billingType,
            isCompleted: existing?.isCompleted ?? false,
            rate: existing?.rate ?? 0.0,
            amount: existing?.amount ?? 0.0,
            vendorRate: existing?.vendorRate ?? 0.0,
            vendorAmount: existing?.vendorAmount ?? 0.0,
          );
          itemFutures.add(
            ref
                .read(orderItemNotifierProvider.notifier)
                .addItem(item, reload: false),
          );
        }
      }

      if (itemFutures.isNotEmpty) {
        await Future.wait(itemFutures);
        ref.read(orderItemNotifierProvider.notifier).loadItems(finalOrderId);
      }

      if (!isDraft) {
        await ref.read(eventRepositoryProvider).syncEventForOrder(order);
        ref.invalidate(eventsStreamProvider);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft
                  ? 'Draft saved successfully'
                  : isEditMode
                      ? 'Order updated successfully'
                      : 'Order confirmed successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        onSavingStateChanged(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        onSavingStateChanged(false);
      }
    }
  }
}
