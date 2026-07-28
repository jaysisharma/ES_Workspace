import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/change_request_entity.dart';
import '../../core/services/fcm_sender.dart';
import 'change_request_providers.dart';
import 'notification_notifier.dart';
import '../../domain/entities/notification_entity.dart';
import 'package:uuid/uuid.dart';

class ChangeRequestState {
  final List<ChangeRequestEntity> requests;
  final bool isLoading;
  final String? error;

  const ChangeRequestState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  ChangeRequestState copyWith({
    List<ChangeRequestEntity>? requests,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChangeRequestState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChangeRequestNotifier extends Notifier<ChangeRequestState> {
  @override
  ChangeRequestState build() {
    return const ChangeRequestState();
  }

  Future<void> loadRequests(String orderId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final getRequestsByOrder = ref.read(
        getChangeRequestsByOrderUseCaseProvider,
      );
      final requests = await getRequestsByOrder(orderId);
      state = state.copyWith(isLoading: false, requests: requests);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createRequest(ChangeRequestEntity request) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final createRequest = ref.read(createChangeRequestUseCaseProvider);
      await createRequest(request);

      // Notify admin + founder of incoming change request
      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: 'New Change Request',
              description:
                  'A new change request was submitted for order ${request.orderId}.',
              timestamp: DateTime.now(),
              type: 'warning',
              relatedId: request.orderId,
              targetRole: 'admin_founder',
            ),
          );
      FcmSender.sendToTopics(
        topics: ['role_admin', 'role_founder'],
        title: 'New Change Request',
        body: 'A new change request was submitted for order ${request.orderId}.',
      );

      await loadRequests(request.orderId); // Refresh list
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateStatus(
    String requestId,
    String orderId,
    String status, {
    String? requestedByUserId, // staff member who submitted the request
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updateRequestStatus = ref.read(
        updateChangeRequestStatusUseCaseProvider,
      );
      await updateRequestStatus(requestId, status);

      // Notify the specific staff member who submitted the request
      final isApproved = status == 'approved';
      final notifTitle = isApproved ? 'Change Request Approved' : 'Change Request Rejected';
      final notifBody = isApproved
          ? 'Your change request for order $orderId has been approved.'
          : 'Your change request for order $orderId has been rejected.';
      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: notifTitle,
              description: notifBody,
              timestamp: DateTime.now(),
              type: 'system',
              relatedId: orderId,
              targetRole: 'staff',
              targetUserId: requestedByUserId,
            ),
          );
      if (requestedByUserId != null) {
        FcmSender.sendToUser(
          userId: requestedByUserId,
          title: notifTitle,
          body: notifBody,
        );
      }

      await loadRequests(orderId); // Refresh list
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
