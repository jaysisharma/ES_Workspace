import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:order_app/domain/entities/event_pass_entity.dart';
import 'package:order_app/domain/repositories/event_pass_repository.dart';
import 'package:order_app/core/errors/failures.dart';

class LocalHttpEventPassRepository implements EventPassRepository {
  final String hostIp;
  final int port;

  LocalHttpEventPassRepository({required this.hostIp, this.port = 8080});

  String get _baseUrl => 'http://$hostIp:$port';

  @override
  Future<List<EventPassEntity>> getAllPasses() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/passes'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((item) => EventPassEntity.fromMap(item as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Failed to load passes: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<void> addPass(EventPassEntity pass) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/addPass'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(pass.toMap()),
      );
      if (response.statusCode != 200) {
        throw ServerException('Failed to add pass: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePass(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deletePass'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode != 200) {
        throw ServerException('Failed to delete pass: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<EventPassEntity?> getPassById(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/getPass?id=$id'));
      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == 'null') return null;
        return EventPassEntity.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ServerException('Failed to fetch pass: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<void> redeemService(String passId, String serviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'passId': passId, 'serviceName': serviceName}),
      );
      if (response.statusCode != 200) {
        throw ServerException(response.body.replaceAll('Exception: ', ''));
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getAvailableServices() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/services'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.cast<String>();
      } else {
        throw ServerException('Failed to load services: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<void> saveAvailableService(String serviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/addService'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': serviceName}),
      );
      if (response.statusCode != 200) {
        throw ServerException('Failed to save service: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAvailableService(String serviceName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deleteService'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': serviceName}),
      );
      if (response.statusCode != 200) {
        throw ServerException('Failed to delete service: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }

  @override
  Future<String> getSecuritySalt() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/config'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['salt'] as String;
      } else {
        throw ServerException('Failed to fetch host config: ${response.body}');
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to communicate with local host: ${e.toString()}');
    }
  }
}
