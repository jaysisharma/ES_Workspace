import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/repositories/firestore_inventory_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────────
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => FirestoreInventoryRepository(),
);

// ── State ──────────────────────────────────────────────────────────────────────
class InventoryState {
  final List<InventoryItemEntity> items;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCategory;
  final String searchQuery;

  const InventoryState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory = 'ALL',
    this.searchQuery = '',
  });

  InventoryState copyWith({
    List<InventoryItemEntity>? items,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return InventoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<InventoryItemEntity> get filteredItems {
    return items.where((item) {
      final matchesCategory = selectedCategory == 'ALL' ||
          item.category.toUpperCase() == selectedCategory.toUpperCase();
      final matchesSearch = searchQuery.isEmpty ||
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.location.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────
class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    Future.microtask(_load);
    return const InventoryState();
  }

  InventoryRepository get _repo => ref.read(inventoryRepositoryProvider);

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repo.getAllInventoryItems();
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _load();

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> addInventoryItem(InventoryItemEntity item) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addInventoryItem(item);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateInventoryItem(InventoryItemEntity item) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updateInventoryItem(item);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deleteInventoryItem(id);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> adjustStock(String id, int delta) async {
    try {
      await _repo.adjustStock(id, delta);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────
final inventoryNotifierProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(
  () => InventoryNotifier(),
);
