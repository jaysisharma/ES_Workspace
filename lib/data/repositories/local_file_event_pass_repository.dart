import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:order_app/domain/entities/event_pass_entity.dart';
import 'package:order_app/domain/repositories/event_pass_repository.dart';
import 'package:order_app/core/errors/failures.dart';

class LocalFileEventPassRepository implements EventPassRepository {
  Future<File> get _passesFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/local_passes.json');
  }

  Future<File> get _servicesFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/local_services.json');
  }

  // Chained lock to prevent concurrent file modifications
  Future<void>? _lock;

  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final previous = _lock;
    final completer = Future.value();
    _lock = completer;
    if (previous != null) {
      await previous;
    }
    try {
      return await action();
    } finally {
      if (identical(_lock, completer)) {
        _lock = null;
      }
    }
  }

  @override
  Future<List<EventPassEntity>> getAllPasses() async {
    return _synchronized(() async {
      try {
        final file = await _passesFile;
        if (!await file.exists()) return [];
        final contents = await file.readAsString();
        if (contents.isEmpty) return [];
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList
            .map((item) => EventPassEntity.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        throw ServerException('Failed to load local passes: ${e.toString()}');
      }
    });
  }

  @override
  Future<void> addPass(EventPassEntity pass) async {
    await _synchronized(() async {
      try {
        final file = await _passesFile;
        List<EventPassEntity> passes = [];
        if (await file.exists()) {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(contents);
            passes = jsonList
                .map((item) => EventPassEntity.fromMap(item as Map<String, dynamic>))
                .toList();
          }
        }
        passes.removeWhere((p) => p.id == pass.id);
        passes.add(pass);
        final jsonList = passes.map((p) => p.toMap()).toList();
        await file.writeAsString(jsonEncode(jsonList));
      } catch (e) {
        throw ServerException('Failed to save local pass: ${e.toString()}');
      }
    });
  }

  @override
  Future<void> deletePass(String id) async {
    await _synchronized(() async {
      try {
        final file = await _passesFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(contents);
            final List<EventPassEntity> passes = jsonList
                .map((item) => EventPassEntity.fromMap(item as Map<String, dynamic>))
                .toList();
            passes.removeWhere((p) => p.id == id);
            final updatedList = passes.map((p) => p.toMap()).toList();
            await file.writeAsString(jsonEncode(updatedList));
          }
        }
      } catch (e) {
        throw ServerException('Failed to delete local pass: ${e.toString()}');
      }
    });
  }

  @override
  Future<EventPassEntity?> getPassById(String id) async {
    final passes = await getAllPasses();
    try {
      return passes.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> redeemService(String passId, String serviceName) async {
    await _synchronized(() async {
      try {
        final file = await _passesFile;
        if (!await file.exists()) throw ServerException('No passes database found');
        
        final contents = await file.readAsString();
        if (contents.isEmpty) throw ServerException('No passes database found');
        
        final List<dynamic> jsonList = jsonDecode(contents);
        final passes = jsonList
            .map((item) => EventPassEntity.fromMap(item as Map<String, dynamic>))
            .toList();

        final passIndex = passes.indexWhere((p) => p.id == passId);
        if (passIndex == -1) throw ServerException('Event pass not found');

        final pass = passes[passIndex];
        bool found = false;
        final updatedServices = pass.services.map((service) {
          if (service.name == serviceName) {
            found = true;
            if (service.isRedeemed) {
              throw ServerException('Service has already been redeemed');
            }
            return service.copyWith(isRedeemed: true, redeemedAt: DateTime.now());
          }
          return service;
        }).toList();

        if (!found) throw ServerException('Service not found on this pass');

        passes[passIndex] = pass.copyWith(services: updatedServices);
        
        final newJsonList = passes.map((p) => p.toMap()).toList();
        await file.writeAsString(jsonEncode(newJsonList));
      } catch (e) {
        if (e is ServerException) rethrow;
        throw ServerException('Failed to redeem service: ${e.toString()}');
      }
    });
  }

  @override
  Future<List<String>> getAvailableServices() async {
    return _synchronized(() async {
      try {
        final file = await _servicesFile;
        if (!await file.exists()) {
          final defaults = ['Dinner', 'Lunch', 'Drinks', 'Photoshoot'];
          await file.writeAsString(jsonEncode(defaults));
          return defaults;
        }
        final contents = await file.readAsString();
        if (contents.isEmpty) return [];
        final List<dynamic> jsonList = jsonDecode(contents);
        return jsonList.cast<String>();
      } catch (e) {
        throw ServerException('Failed to load local services: ${e.toString()}');
      }
    });
  }

  Future<File> get _settingsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/local_settings.json');
  }

  @override
  Future<void> saveAvailableService(String serviceName) async {
    await _synchronized(() async {
      try {
        final file = await _servicesFile;
        List<String> services = [];
        if (await file.exists()) {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(contents);
            services = jsonList.cast<String>();
          }
        }
        if (!services.contains(serviceName)) {
          services.add(serviceName);
          await file.writeAsString(jsonEncode(services));
        }
      } catch (e) {
        throw ServerException('Failed to save local service: ${e.toString()}');
      }
    });
  }

  @override
  Future<void> deleteAvailableService(String serviceName) async {
    await _synchronized(() async {
      try {
        final file = await _servicesFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(contents);
            final List<String> services = jsonList.cast<String>();
            services.remove(serviceName);
            await file.writeAsString(jsonEncode(services));
          }
        }
      } catch (e) {
        throw ServerException('Failed to delete local service: ${e.toString()}');
      }
    });
  }

  @override
  Future<String> getSecuritySalt() async {
    return _synchronized(() async {
      try {
        final file = await _settingsFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          if (contents.isNotEmpty) {
            final Map<String, dynamic> data = jsonDecode(contents);
            if (data.containsKey('salt')) {
              return data['salt'] as String;
            }
          }
        }
        final newSalt = 'local_salt_${DateTime.now().millisecondsSinceEpoch}';
        await file.writeAsString(jsonEncode({'salt': newSalt}));
        return newSalt;
      } catch (e) {
        throw ServerException('Failed to load local security salt: ${e.toString()}');
      }
    });
  }
}
