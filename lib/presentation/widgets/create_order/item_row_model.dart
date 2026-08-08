import 'package:flutter/material.dart';

class ItemRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController daysController = TextEditingController(text: '1');
  final TextEditingController vendorController = TextEditingController();
  String billingType = 'daily';
  final TextEditingController unitController = TextEditingController(
    text: 'Pcs',
  );

  void dispose() {
    nameController.dispose();
    specController.dispose();
    qtyController.dispose();
    daysController.dispose();
    vendorController.dispose();
    unitController.dispose();
  }
}
