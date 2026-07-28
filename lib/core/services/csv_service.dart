import 'package:csv/csv.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/client_entity.dart';
import '../../domain/entities/vendor_entity.dart';

class CsvService {
  static String generateOrdersCsv(List<OrderEntity> orders) {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Order ID',
      'Event Name',
      'Venue',
      'Contact Person',
      'Contact Number',
      'Event Start',
      'Event End',
      'Setup Start',
      'Setup End',
      'Status',
      'Total Amount',
      'Description',
    ]);

    // Data rows
    for (var order in orders) {
      rows.add([
        order.id,
        order.eventName,
        order.venue,
        order.contactPerson,
        order.contactNumber,
        order.eventDate.toString(),
        order.eventEndDate?.toString() ?? '',
        order.setupDate.toString(),
        order.setupEndDate?.toString() ?? '',
        order.status.name,
        order.totalAmount,
        order.description,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static String generateClientsCsv(List<ClientEntity> clients) {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Client Name',
      'Contact Person',
      'Phone',
      'Email',
      'Notes',
    ]);

    // Data rows
    for (var client in clients) {
      rows.add([
        client.name,
        client.contactPerson,
        client.phone,
        client.email,
        client.notes,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static String generateVendorsCsv(List<VendorEntity> vendors) {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Vendor Name',
      'Contact Person',
      'Phone',
      'Email',
      'Notes',
    ]);

    // Data rows
    for (var vendor in vendors) {
      rows.add([
        vendor.name,
        vendor.contactPerson,
        vendor.phone,
        vendor.email,
        vendor.notes,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
