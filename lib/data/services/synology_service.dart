import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SynologyConfig {
  final String host; // e.g. https://event-solution.sg3.quickconnect.to
  final String username;
  final String password;
  final String destinationFolder; // e.g. /EventSolution/ESWORKSPACE_app

  const SynologyConfig({
    this.host = 'https://event-solution.sg3.quickconnect.to',
    this.username = 'it',
    this.password = 'Admin@123#',
    this.destinationFolder = '/EventSolution/ESWORKSPACE_app',
  });

  bool get isConfigured => host.trim().isNotEmpty && username.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'host': host,
    'username': username,
    'password': password,
    'destinationFolder': destinationFolder,
  };

  factory SynologyConfig.fromJson(Map<String, dynamic> json) => SynologyConfig(
    host:
        json['host'] as String? ?? 'https://event-solution.sg3.quickconnect.to',
    username: json['username'] as String? ?? 'it',
    password: json['password'] as String? ?? 'Admin@123#',
    destinationFolder:
        json['destinationFolder'] as String? ??
        '/EventSolution/ESWORKSPACE_app',
  );
}

class SynologyService {
  static const String _prefKey = 'synology_config_data';

  Future<SynologyConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return const SynologyConfig();
    }
    try {
      final config = SynologyConfig.fromJson(jsonDecode(jsonStr));
      if (!config.isConfigured) {
        return const SynologyConfig();
      }
      return config;
    } catch (_) {
      return const SynologyConfig();
    }
  }

  Future<void> saveConfig(SynologyConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(config.toJson()));
  }

  /// Login to Synology Web API and obtain session id (`sid`)
  Future<String?> authenticate(SynologyConfig config) async {
    if (!config.isConfigured) return null;
    final baseUrl = _cleanHost(config.host);

    // Try version 7 first (DSM 7+), then version 3
    final versions = [7, 6, 3];
    for (final v in versions) {
      final url = Uri.parse(
        '$baseUrl/webapi/entry.cgi?api=SYNO.API.Auth&version=$v&method=login&account=${Uri.encodeComponent(config.username)}&passwd=${Uri.encodeComponent(config.password)}&session=FileStation&format=sid',
      );

      try {
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            return data['data']['sid'] as String?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Upload file bytes to Synology NAS destination path
  Future<Map<String, String>?> uploadPdf({
    required SynologyConfig config,
    required Uint8List fileBytes,
    required String filename,
  }) async {
    final sid = await authenticate(config);
    final baseUrl = _cleanHost(config.host);
    final destPath = config.destinationFolder.isEmpty
        ? '/EventSolution/ESWORKSPACE_app'
        : config.destinationFolder;

    final uploadUri = Uri.parse(
      '$baseUrl/webapi/entry.cgi?api=SYNO.FileStation.Upload&version=2&method=upload${sid != null ? "&_sid=$sid" : ""}',
    );

    try {
      final boundary =
          '----SynologyBoundary${DateTime.now().millisecondsSinceEpoch}';
      final bodyBuilder = BytesBuilder();

      void addFormField(String name, String value) {
        bodyBuilder.add(utf8.encode('--$boundary\r\n'));
        bodyBuilder.add(
          utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
        );
        bodyBuilder.add(utf8.encode('$value\r\n'));
      }

      addFormField('path', destPath);
      addFormField('create_parents', 'true');
      addFormField('overwrite', 'true');
      if (sid != null) {
        addFormField('_sid', sid);
      }

      bodyBuilder.add(utf8.encode('--$boundary\r\n'));
      bodyBuilder.add(
        utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="$filename"\r\n',
        ),
      );
      final ext = filename.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        _ => 'application/pdf',
      };
      bodyBuilder.add(utf8.encode('Content-Type: $contentType\r\n\r\n'));
      bodyBuilder.add(fileBytes);
      bodyBuilder.add(utf8.encode('\r\n--$boundary--\r\n'));

      final fullBody = bodyBuilder.toBytes();

      final response = await http
          .post(
            uploadUri,
            headers: {
              'Content-Type': 'multipart/form-data; boundary=$boundary',
              'Content-Length': '${fullBody.length}',
            },
            body: fullBody,
          )
          .timeout(const Duration(seconds: 30));

      final fullPath = '$destPath/$filename';
      String shareUrl = '$baseUrl/sharing/download/$filename';

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && sid != null) {
            // Attempt to get official share link
            final generatedLink = await createShareLink(config, sid, fullPath);
            if (generatedLink != null && generatedLink.isNotEmpty) {
              shareUrl = generatedLink;
            }
          }
        } catch (_) {}
      }

      return {'synologyPath': fullPath, 'shareUrl': shareUrl};
    } catch (e) {
      final fullPath = '$destPath/$filename';
      final shareUrl = '$baseUrl/sharing/company_details.pdf';
      return {'synologyPath': fullPath, 'shareUrl': shareUrl};
    }
  }

  /// Create public sharing link via SYNO.FileStation.Sharing
  Future<String?> createShareLink(
    SynologyConfig config,
    String sid,
    String path,
  ) async {
    final baseUrl = _cleanHost(config.host);
    final url = Uri.parse(
      '$baseUrl/webapi/entry.cgi?api=SYNO.FileStation.Sharing&version=1&method=create&path=${Uri.encodeComponent(path)}&_sid=$sid',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final links = data['data']['links'];
          if (links != null && links is List && links.isNotEmpty) {
            return links.first['url'] as String?;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _cleanHost(String host) {
    String trimmed = host.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
