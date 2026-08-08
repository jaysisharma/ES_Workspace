import 'package:flutter/material.dart';

class RevenueDescriptionCardWidget extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final Color labelColor;
  final Color borderColor;
  final Color containerBgColor;

  const RevenueDescriptionCardWidget({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.labelColor,
    required this.borderColor,
    required this.containerBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'ORDER DESCRIPTION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add overall order notes...',
            filled: true,
            fillColor: containerBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }
}
