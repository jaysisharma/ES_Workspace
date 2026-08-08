import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/change_request_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/change_request_providers.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsChangeRequestsWidget extends ConsumerWidget {
  final String orderId;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  const OrderDetailsChangeRequestsWidget({
    super.key,
    required this.orderId,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestState = ref.watch(changeRequestNotifierProvider);
    final userRole = ref.watch(authNotifierProvider).user?.role;
    final isAdminOrFounder = userRole == UserRole.admin || userRole == UserRole.founder;

    final defaultWellColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: defaultWellColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabelWidget(
                'CHANGE REQUESTS',
                labelColor: labelColor,
                accentColor: warningColor,
              ),
              if (requestState.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (requestState.requests.isEmpty && !requestState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No change requests for this order.',
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
            )
          else
            ...requestState.requests.map((request) {
              Color statusColor;
              switch (request.status) {
                case ChangeStatus.approved:
                  statusColor = successColor;
                  break;
                case ChangeStatus.rejected:
                  statusColor = errorColor;
                  break;
                default:
                  statusColor = warningColor;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          request.changeType,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            request.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.description,
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatNepaliDate(request.createdAt, 'MMMM dd')}, ${DateFormat('h:mm a').format(request.createdAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: labelColor.withValues(alpha: 0.6),
                      ),
                    ),
                    if (request.status == ChangeStatus.pending && isAdminOrFounder) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(changeRequestNotifierProvider.notifier)
                                    .updateStatus(
                                      request.id,
                                      request.orderId,
                                      ChangeStatus.approved.name,
                                      requestedByUserId: request.requestedBy,
                                    );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: successColor,
                                side: BorderSide(color: successColor),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(changeRequestNotifierProvider.notifier)
                                    .updateStatus(
                                      request.id,
                                      request.orderId,
                                      ChangeStatus.rejected.name,
                                      requestedByUserId: request.requestedBy,
                                    );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: errorColor,
                                side: BorderSide(color: errorColor),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
