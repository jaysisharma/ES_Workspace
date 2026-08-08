import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:order_app/data/repositories/local_file_event_pass_repository.dart';
import 'package:order_app/domain/entities/event_pass_entity.dart';

class LocalPassServer {
  final LocalFileEventPassRepository _repo = LocalFileEventPassRepository();
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  Timer? _udpTimer;
  String? _salt;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  static Future<String> getHostIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          // Typically Wi-Fi interface names contain "en", "wlan", "ap" or "wl"
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> start({int port = 8080}) async {
    if (_isRunning) return;

    try {
      _salt = await _repo.getSecuritySalt();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;

      final ip = await getHostIpAddress();
      _startUdpBroadcaster(ip, _salt ?? '');

      _listen();
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  void _startUdpBroadcaster(String ip, String salt) async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket?.broadcastEnabled = true;
      _udpTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!_isRunning || _udpSocket == null) {
          timer.cancel();
          return;
        }
        final packet = jsonEncode({'hostIp': ip, 'salt': salt});
        final bytes = utf8.encode(packet);
        _udpSocket?.send(
          bytes,
          InternetAddress('255.255.255.255'),
          8888,
        );
      });
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _udpTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    _udpTimer = null;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  void _listen() {
    _server?.listen((HttpRequest request) async {
      // Set CORS Headers to allow any local connections
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path;

      try {
        if (path == '/passes' && request.method == 'GET') {
          final passes = await _repo.getAllPasses();
          final data = passes.map((p) => p.toMap()).toList();
          _sendJsonResponse(request, data);
        } else if (path == '/addPass' && request.method == 'POST') {
          final body = await _readRequestBody(request);
          final pass = EventPassEntity.fromMap(jsonDecode(body));
          await _repo.addPass(pass);
          _sendOkResponse(request);
        } else if (path == '/deletePass' && request.method == 'POST') {
          final body = await _readRequestBody(request);
          final data = jsonDecode(body);
          final id = data['id'];
          if (id == null) {
            _sendErrorResponse(request, 'Missing id parameter', HttpStatus.badRequest);
            return;
          }
          await _repo.deletePass(id);
          _sendOkResponse(request);
        } else if (path == '/getPass' && request.method == 'GET') {
          final id = request.uri.queryParameters['id'];
          if (id == null) {
            _sendErrorResponse(request, 'Missing id parameter', HttpStatus.badRequest);
            return;
          }
          final pass = await _repo.getPassById(id);
          _sendJsonResponse(request, pass?.toMap());
        } else if (path == '/redeem' && request.method == 'POST') {
          final body = await _readRequestBody(request);
          final data = jsonDecode(body);
          final passId = data['passId'];
          final serviceName = data['serviceName'];
          if (passId == null || serviceName == null) {
            _sendErrorResponse(request, 'Missing passId or serviceName', HttpStatus.badRequest);
            return;
          }
          await _repo.redeemService(passId, serviceName);
          _sendOkResponse(request);
        } else if (path == '/services' && request.method == 'GET') {
          final services = await _repo.getAvailableServices();
          _sendJsonResponse(request, services);
        } else if (path == '/addService' && request.method == 'POST') {
          final body = await _readRequestBody(request);
          final data = jsonDecode(body);
          final name = data['name'];
          if (name == null) {
            _sendErrorResponse(request, 'Missing service name', HttpStatus.badRequest);
            return;
          }
          await _repo.saveAvailableService(name);
          _sendOkResponse(request);
        } else if (path == '/deleteService' && request.method == 'POST') {
          final body = await _readRequestBody(request);
          final data = jsonDecode(body);
          final name = data['name'];
          if (name == null) {
            _sendErrorResponse(request, 'Missing service name', HttpStatus.badRequest);
            return;
          }
          await _repo.deleteAvailableService(name);
          _sendOkResponse(request);
        } else if (path == '/config' && request.method == 'GET') {
          _sendJsonResponse(request, {'salt': _salt ?? ''});
        } else {
          _sendErrorResponse(request, 'Not Found', HttpStatus.notFound);
        }
      } catch (e) {
        _sendErrorResponse(request, e.toString(), HttpStatus.internalServerError);
      }
    });
  }

  Future<String> _readRequestBody(HttpRequest request) async {
    return await utf8.decoder.bind(request).join();
  }

  void _sendJsonResponse(HttpRequest request, dynamic data) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  void _sendOkResponse(HttpRequest request) {
    request.response.statusCode = HttpStatus.ok;
    request.response.write('OK');
    request.response.close();
  }

  void _sendErrorResponse(HttpRequest request, String message, int statusCode) {
    request.response.statusCode = statusCode;
    request.response.write(message);
    request.response.close();
  }
}
