import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import 'package:order_app/domain/repositories/purchase_order_repository.dart';
import 'package:order_app/data/repositories/purchase_order_repository_impl.dart';
import 'package:order_app/data/datasources/remote/firestore_purchase_order_remote_datasource.dart';

// Data Source
final purchaseOrderRemoteDataSourceProvider =
    Provider<PurchaseOrderRemoteDataSource>((ref) {
      return FirestorePurchaseOrderRemoteDataSource();
    });

// Repository
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((
  ref,
) {
  final dataSource = ref.watch(purchaseOrderRemoteDataSourceProvider);
  return PurchaseOrderRepositoryImpl(remoteDataSource: dataSource);
});

// Notifier State
class PurchaseOrderState {
  final List<PurchaseOrderEntity> pos;
  final bool isLoading;
  final String? error;

  const PurchaseOrderState({
    this.pos = const [],
    this.isLoading = false,
    this.error,
  });

  PurchaseOrderState copyWith({
    List<PurchaseOrderEntity>? pos,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PurchaseOrderState(
      pos: pos ?? this.pos,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Notifier
class PurchaseOrderNotifier extends Notifier<PurchaseOrderState> {
  @override
  PurchaseOrderState build() {
    return const PurchaseOrderState();
  }

  Future<void> loadPurchaseOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pos = await ref
          .read(purchaseOrderRepositoryProvider)
          .getPurchaseOrders();
      state = state.copyWith(pos: pos, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> create(PurchaseOrderEntity po) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).createPurchaseOrder(po);
      await loadPurchaseOrders();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> update(PurchaseOrderEntity po) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).updatePurchaseOrder(po);
      await loadPurchaseOrders();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(purchaseOrderRepositoryProvider).deletePurchaseOrder(id);
      await loadPurchaseOrders();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final purchaseOrderNotifierProvider =
    NotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>(() {
      return PurchaseOrderNotifier();
    });

final purchaseOrdersStreamProvider = StreamProvider<List<PurchaseOrderEntity>>((
  ref,
) {
  final repository = ref.watch(purchaseOrderRepositoryProvider);
  return repository.getPurchaseOrdersStream();
});
