import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SynologyStorageService {
  static const String _prefHostKey = 'synology_nas_host';
  static const String _prefFolderKey = 'synology_nas_folder';
  static const String _prefAccountKey = 'synology_nas_account';
  static const String _prefPasswordKey = 'synology_nas_password';
  static const String _prefEnabledKey = 'synology_nas_enabled';

  static Future<void> saveSettings({
    required String hostUrl,
    required String folderPath,
    required String account,
    required String password,
    required bool isEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefHostKey, hostUrl.trim());
    await prefs.setString(_prefFolderKey, folderPath.trim());
    await prefs.setString(_prefAccountKey, account.trim());
    await prefs.setString(_prefPasswordKey, password.trim());
    await prefs.setBool(_prefEnabledKey, isEnabled);
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hostUrl': prefs.getString(_prefHostKey) ?? 'http://192.168.1.100:5000',
      'folderPath': prefs.getString(_prefFolderKey) ?? '/volume1/hr_documents',
      'account': prefs.getString(_prefAccountKey) ?? 'admin',
      'password': prefs.getString(_prefPasswordKey) ?? '',
      'isEnabled': prefs.getBool(_prefEnabledKey) ?? false,
    };
  }

  /// Uploads image bytes to Synology NAS FileStation API / WebDAV.
  /// Returns the Synology file URL on success, or base64 data URI fallback.
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final config = await loadSettings();
    final bool isEnabled = config['isEnabled'] ?? false;
    final String hostUrl = config['hostUrl'] ?? '';
    final String folderPath = config['folderPath'] ?? '/volume1/hr_documents';
    final String account = config['account'] ?? '';
    final String password = config['password'] ?? '';

    // If Synology NAS upload is disabled or unconfigured, return base64 data URI
    if (!isEnabled || hostUrl.isEmpty) {
      final base64Str = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Str';
    }

    try {
      final cleanHost = hostUrl.endsWith('/')
          ? hostUrl.substring(0, hostUrl.length - 1)
          : hostUrl;

      // 1. Authenticate with Synology FileStation API to obtain sid session token
      final authUri = Uri.parse(
          '$cleanHost/webapi/auth.cgi?api=SYNO.API.Auth&version=3&method=login&account=${Uri.encodeComponent(account)}&passwd=${Uri.encodeComponent(password)}&session=FileStation&format=cookie');

      final authResponse = await http.get(authUri).timeout(const Duration(seconds: 5));
      String sid = '';

      if (authResponse.statusCode == 200) {
        final authJson = jsonDecode(authResponse.body);
        if (authJson['success'] == true && authJson['data']?['sid'] != null) {
          sid = authJson['data']['sid'];
        }
      }

      // 2. Upload image file to Synology NAS FileStation
      final uploadUri = Uri.parse('$cleanHost/webapi/entry.cgi');
      final request = http.MultipartRequest('POST', uploadUri);

      request.fields['api'] = 'SYNO.FileStation.Upload';
      request.fields['version'] = '2';
      request.fields['method'] = 'upload';
      request.fields['path'] = folderPath;
      request.fields['create_parents'] = 'true';
      if (sid.isNotEmpty) {
        request.fields['_sid'] = sid;
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename.endsWith('.jpg') ? filename : '$filename.jpg',
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        if (resJson['success'] == true) {
          // Construct public/network Synology file URL
          final cleanFolder = folderPath.startsWith('/volume1')
              ? folderPath.replaceFirst('/volume1', '')
              : folderPath;
          return '$cleanHost$cleanFolder/$filename.jpg';
        }
      }
    } catch (e) {
      // If NAS upload fails due to network/IP issues, fallback to base64 data URI cleanly
      print('Synology NAS upload warning: $e. Falling back to local data URI.');
    }

    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
  }
}
