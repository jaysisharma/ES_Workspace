import 'package:flutter/material.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsHeaderWidget extends StatelessWidget {
  final OrderEntity order;
  final Color statusColor;
  final Color statusWellColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final String Function(OrderStatus) statusLabel;

  const OrderDetailsHeaderWidget({
    super.key,
    required this.order,
    required this.statusColor,
    required this.statusWellColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusWellColor,
            statusWellColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      statusLabel(order.status).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: order.orderType.toLowerCase() == 'rental'
                          ? const Color(0xFF8b5cf6).withValues(alpha: 0.15)
                          : primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: order.orderType.toLowerCase() == 'rental'
                            ? const Color(0xFF8b5cf6).withValues(alpha: 0.35)
                            : primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.orderType.toLowerCase() == 'rental'
                              ? Icons.inventory_2_outlined
                              : Icons.celebration_outlined,
                          size: 11,
                          color: order.orderType.toLowerCase() == 'rental'
                              ? const Color(0xFF8b5cf6)
                              : primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (order.orderType.isNotEmpty ? order.orderType : 'Event').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: order.orderType.toLowerCase() == 'rental'
                                ? const Color(0xFF8b5cf6)
                                : primaryColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                'ID: ${order.id.length > 10 ? order.id.substring(0, 10) : order.id}',
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            order.eventName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          InfoRowWidget(
            icon: Icons.calendar_today_outlined,
            text: () {
              final start = order.eventDate;
              final end = order.eventEndDate;
              if (end == null ||
                  (end.year == start.year &&
                      end.month == start.month &&
                      end.day == start.day)) {
                return formatNepaliDate(start, 'MMMM dd, yyyy');
              }
              return '${formatNepaliDate(start, 'MMMM dd')} – ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
            }(),
            color: primaryColor,
            labelColor: labelColor,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            icon: Icons.location_on_outlined,
            text: order.venue,
            color: primaryColor,
            labelColor: labelColor,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            icon: Icons.person_outline_rounded,
            text: '${order.contactPerson}  •  ${order.contactNumber}',
            color: primaryColor,
            labelColor: labelColor,
          ),
        ],
      ),
    );
  }
}
