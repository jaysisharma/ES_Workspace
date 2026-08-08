import 'package:flutter/material.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsEventDatesWidget extends StatelessWidget {
  final OrderEntity order;
  final Color defaultWellColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;

  const OrderDetailsEventDatesWidget({
    super.key,
    required this.order,
    required this.defaultWellColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: defaultWellColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabelWidget(
            'EVENT DETAILS',
            labelColor: labelColor,
            accentColor: primaryColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DetailCellWidget(
                  label: 'Setup Date',
                  value: () {
                    final start = order.setupDate;
                    final end = order.setupEndDate;
                    if (end == null ||
                        (end.year == start.year &&
                            end.month == start.month &&
                            end.day == start.day)) {
                      return formatNepaliDate(
                        start,
                        'MMMM dd, yyyy',
                      );
                    }
                    if (start.year == end.year) {
                      return '${formatNepaliDate(start, 'MMMM dd')} - ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
                    }
                    return '${formatNepaliDate(start, 'MMMM dd, yyyy')} - ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
                  }(),
                  textColor: textColor,
                  labelColor: labelColor,
                ),
              ),
              Expanded(
                child: DetailCellWidget(
                  label: 'Event Date',
                  value: () {
                    final start = order.eventDate;
                    final end = order.eventEndDate;
                    if (end == null ||
                        (end.year == start.year &&
                            end.month == start.month &&
                            end.day == start.day)) {
                      return formatNepaliDate(
                        start,
                        'MMMM dd, yyyy',
                      );
                    }
                    return '${formatNepaliDate(start, 'MMMM dd')} – ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
                  }(),
                  textColor: textColor,
                  labelColor: labelColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
