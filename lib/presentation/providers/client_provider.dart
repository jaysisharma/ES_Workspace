import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/client_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../../data/repositories/firestore_client_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────
final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => FirestoreClientRepository(),
);

// ── State ─────────────────────────────────────────────────────────────────────
class ClientState {
  final List<ClientEntity> clients;
  final bool isLoading;
  final String? errorMessage;

  const ClientState({
    this.clients = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ClientState copyWith({
    List<ClientEntity>? clients,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ClientState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class ClientNotifier extends Notifier<ClientState> {
  @override
  ClientState build() {
    Future.microtask(_load);
    return const ClientState();
  }

  ClientRepository get _repo => ref.read(clientRepositoryProvider);

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final clients = await _repo.getAllClients();
      state = state.copyWith(isLoading: false, clients: clients);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<bool> addClient(ClientEntity client) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addClient(client);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateClient(ClientEntity client) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updateClient(client);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deleteClient(id);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final clientNotifierProvider = NotifierProvider<ClientNotifier, ClientState>(
  () => ClientNotifier(),
);
