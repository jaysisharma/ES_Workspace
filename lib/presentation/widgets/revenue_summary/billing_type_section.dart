import 'package:flutter/material.dart';

class BillingTypeSection extends StatelessWidget {
  final String billingType;
  final ValueChanged<String> onBillingTypeChanged;
  final int maxDays;
  final bool includeDrafts;
  final ValueChanged<bool> onIncludeDraftsChanged;

  const BillingTypeSection({
    super.key,
    required this.billingType,
    required this.onBillingTypeChanged,
    required this.maxDays,
    required this.includeDrafts,
    required this.onIncludeDraftsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BILLING TYPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: labelColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: billingType,
            items: ['Multi-Day Event', 'Single Day Event']
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                onBillingTypeChanged(val);
              }
            },
            dropdownColor: colorScheme.surface,
            icon: Icon(Icons.expand_more, color: labelColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '* Individual items can have their own billing type (Daily or Event) set in the order details.',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Event Duration',
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$maxDays ${maxDays == 1 ? 'Day' : 'Days'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Include Draft Orders',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.info_outline, size: 14, color: labelColor),
                ],
              ),
              Switch.adaptive(
                value: includeDrafts,
                activeTrackColor: colorScheme.primary,
                onChanged: onIncludeDraftsChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
