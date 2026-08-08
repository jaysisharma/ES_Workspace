import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:order_app/domain/entities/event_pass_entity.dart';
import 'package:order_app/domain/repositories/event_pass_repository.dart';
import 'package:order_app/data/repositories/firestore_event_pass_repository.dart';
import 'package:order_app/data/repositories/local_file_event_pass_repository.dart';
import 'package:order_app/data/repositories/local_http_event_pass_repository.dart';
import 'package:order_app/core/services/local_pass_server.dart';

// ── Sync Modes ───────────────────────────────────────────────────────────────
enum PassSyncMode { cloud, localHost, localClient }

class SyncState {
  final PassSyncMode mode;
  final String hostIp;
  final String deviceIp;
  final String salt;
  final bool isServerRunning;
  final bool isReconciling;

  SyncState({
    this.mode = PassSyncMode.cloud,
    this.hostIp = '',
    this.deviceIp = '',
    this.salt = '',
    this.isServerRunning = false,
    this.isReconciling = false,
  });

  SyncState copyWith({
    PassSyncMode? mode,
    String? hostIp,
    String? deviceIp,
    String? salt,
    bool? isServerRunning,
    bool? isReconciling,
  }) {
    return SyncState(
      mode: mode ?? this.mode,
      hostIp: hostIp ?? this.hostIp,
      deviceIp: deviceIp ?? this.deviceIp,
      salt: salt ?? this.salt,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      isReconciling: isReconciling ?? this.isReconciling,
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  final LocalPassServer _server = LocalPassServer();
  RawDatagramSocket? _udpClientSocket;

  @override
  SyncState build() {
    _updateDeviceIp();
    _startUdpListener();
    _loadCloudSalt();

    ref.onDispose(() {
      _server.stop();
      _udpClientSocket?.close();
    });

    return SyncState();
  }

  Future<void> _updateDeviceIp() async {
    final ip = await LocalPassServer.getHostIpAddress();
    state = state.copyWith(deviceIp: ip);
  }

  Future<void> _loadCloudSalt() async {
    try {
      final repo = FirestoreEventPassRepository();
      final salt = await repo.getSecuritySalt();
      state = state.copyWith(salt: salt);
    } catch (_) {}
  }

  void _startUdpListener() async {
    try {
      _udpClientSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8888,
      );
      _udpClientSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpClientSocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final data = jsonDecode(text);
              final ip = data['hostIp'];
              final salt = data['salt'];
              if (ip != null && salt != null) {
                if (state.mode == PassSyncMode.localClient) {
                  if (state.hostIp != ip) {
                    state = state.copyWith(hostIp: ip, salt: salt);
                    ref.read(eventPassNotifierProvider.notifier).refresh();
                  } else {
                    state = state.copyWith(salt: salt);
                  }
                } else {
                  state = state.copyWith(hostIp: ip);
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (_) {}
  }

  Future<void> setCloudMode() async {
    if (state.mode == PassSyncMode.localHost) {
      await reconcileLocalDataToCloud();
    }
    await _server.stop();

    try {
      final repo = FirestoreEventPassRepository();
      final salt = await repo.getSecuritySalt();
      state = state.copyWith(
        mode: PassSyncMode.cloud,
        salt: salt,
        isServerRunning: false,
      );
    } catch (_) {
      state = state.copyWith(mode: PassSyncMode.cloud, isServerRunning: false);
    }
    ref.read(eventPassNotifierProvider.notifier).refresh();
  }

  Future<void> setHostMode() async {
    await _server.stop();
    await _server.start();
    final ip = await LocalPassServer.getHostIpAddress();
    final localRepo = LocalFileEventPassRepository();
    final salt = await localRepo.getSecuritySalt();

    state = state.copyWith(
      mode: PassSyncMode.localHost,
      hostIp: ip,
      deviceIp: ip,
      salt: salt,
      isServerRunning: true,
    );
    ref.read(eventPassNotifierProvider.notifier).refresh();
  }

  Future<void> setClientMode(String hostIp) async {
    await _server.stop();
    String salt = '';
    try {
      final repo = LocalHttpEventPassRepository(hostIp: hostIp);
      salt = await repo.getSecuritySalt();
    } catch (_) {}

    state = state.copyWith(
      mode: PassSyncMode.localClient,
      hostIp: hostIp,
      salt: salt,
      isServerRunning: false,
    );
    ref.read(eventPassNotifierProvider.notifier).refresh();
  }

  Future<void> reconcileLocalDataToCloud() async {
    state = state.copyWith(isReconciling: true);
    try {
      final localRepo = LocalFileEventPassRepository();
      final localPasses = await localRepo.getAllPasses();

      final cloudRepo = FirestoreEventPassRepository();
      final cloudSalt = await cloudRepo.getSecuritySalt();

      for (final localPass in localPasses) {
        final cloudPass = await cloudRepo.getPassById(localPass.id);
        if (cloudPass == null) {
          final regeneratedSignature = EventPassEntity.generateSignature(
            localPass.id,
            cloudSalt,
          );
          final passToUpload = localPass.copyWith(
            passSignature: regeneratedSignature,
          );
          await cloudRepo.addPass(passToUpload);
        } else {
          bool needsUpdate = false;
          final updatedServices = cloudPass.services.map((cloudService) {
            final localService = localPass.services.firstWhere(
              (s) => s.name == cloudService.name,
              orElse: () => cloudService,
            );
            if (localService.isRedeemed && !cloudService.isRedeemed) {
              needsUpdate = true;
              return cloudService.copyWith(
                isRedeemed: true,
                redeemedAt: localService.redeemedAt,
              );
            }
            return cloudService;
          }).toList();

          if (needsUpdate) {
            await cloudRepo.addPass(
              cloudPass.copyWith(services: updatedServices),
            );
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/local_passes.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
    } finally {
      state = state.copyWith(isReconciling: false);
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  () => SyncNotifier(),
);

// ── Repository provider ───────────────────────────────────────────────────────
final eventPassRepositoryProvider = Provider<EventPassRepository>((ref) {
  final syncState = ref.watch(syncProvider);
  switch (syncState.mode) {
    case PassSyncMode.cloud:
      return FirestoreEventPassRepository();
    case PassSyncMode.localHost:
      return LocalFileEventPassRepository();
    case PassSyncMode.localClient:
      return LocalHttpEventPassRepository(hostIp: syncState.hostIp);
  }
});

// ── State ─────────────────────────────────────────────────────────────────────
class EventPassState {
  final List<EventPassEntity> passes;
  final List<String> availableServices;
  final bool isLoading;
  final String? errorMessage;

  const EventPassState({
    this.passes = const [],
    this.availableServices = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EventPassState copyWith({
    List<EventPassEntity>? passes,
    List<String>? availableServices,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EventPassState(
      passes: passes ?? this.passes,
      availableServices: availableServices ?? this.availableServices,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class EventPassNotifier extends Notifier<EventPassState> {
  @override
  EventPassState build() {
    Future.microtask(_load);
    return const EventPassState();
  }

  EventPassRepository get _repo => ref.read(eventPassRepositoryProvider);

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final passes = await _repo.getAllPasses();
      final services = await _repo.getAvailableServices();
      state = state.copyWith(
        isLoading: false,
        passes: passes,
        availableServices: services,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<bool> addPass(EventPassEntity pass) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addPass(pass);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deletePass(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deletePass(id);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> addAvailableService(String serviceName) async {
    try {
      await _repo.saveAvailableService(serviceName);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteAvailableService(String serviceName) async {
    try {
      await _repo.deleteAvailableService(serviceName);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> redeemService(String passId, String serviceName) async {
    try {
      await _repo.redeemService(passId, serviceName);
      await _load();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final eventPassNotifierProvider =
    NotifierProvider<EventPassNotifier, EventPassState>(
      () => EventPassNotifier(),
    );
