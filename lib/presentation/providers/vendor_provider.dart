import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/vendor_entity.dart';
import 'package:order_app/domain/repositories/vendor_repository.dart';
import 'package:order_app/data/repositories/firestore_vendor_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────
final vendorRepositoryProvider = Provider<VendorRepository>(
  (ref) => FirestoreVendorRepository(),
);

// ── State ─────────────────────────────────────────────────────────────────────
class VendorState {
  final List<VendorEntity> vendors;
  final bool isLoading;
  final String? errorMessage;

  const VendorState({
    this.vendors = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  VendorState copyWith({
    List<VendorEntity>? vendors,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VendorState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class VendorNotifier extends Notifier<VendorState> {
  @override
  VendorState build() {
    Future.microtask(_load);
    return const VendorState();
  }

  VendorRepository get _repo => ref.read(vendorRepositoryProvider);

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final vendors = await _repo.getAllVendors();
      state = state.copyWith(isLoading: false, vendors: vendors);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<bool> addVendor(VendorEntity vendor) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addVendor(vendor);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateVendor(VendorEntity vendor) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updateVendor(vendor);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteVendor(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deleteVendor(id);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final vendorNotifierProvider = NotifierProvider<VendorNotifier, VendorState>(
  () => VendorNotifier(),
);
