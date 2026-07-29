import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Synology upload test with explicit content length', () async {
    final host = 'https://event-solution.sg3.quickconnect.to';
    final username = 'it';
    final password = 'Admin@123#';

    print('Testing auth with host: $host');
    final url = Uri.parse(
        '$host/webapi/entry.cgi?api=SYNO.API.Auth&version=7&method=login&account=${Uri.encodeComponent(username)}&passwd=${Uri.encodeComponent(password)}&session=FileStation&format=sid');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      print('Auth Response Status: ${response.statusCode}');
      print('Auth Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sid = data['data']?['sid'];
        print('Obtained SID: $sid');

        if (sid != null) {
          final destPath = '/EventSolution/ESWORKSPACE_app';
          final filename = 'test_company_dart_fixed.pdf';
          final fileBytes = utf8.encode('Sample PDF File Content for testing ES Workspace Synology integration');

          final uploadUrl = Uri.parse(
              '$host/webapi/entry.cgi?api=SYNO.FileStation.Upload&version=2&method=upload&_sid=$sid');

          final boundary = '----SynologyBoundary${DateTime.now().millisecondsSinceEpoch}';
          final bodyBuilder = BytesBuilder();

          void addFormField(String name, String value) {
            bodyBuilder.add(utf8.encode('--$boundary\r\n'));
            bodyBuilder.add(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
            bodyBuilder.add(utf8.encode('$value\r\n'));
          }

          addFormField('path', destPath);
          addFormField('create_parents', 'true');
          addFormField('overwrite', 'true');

          bodyBuilder.add(utf8.encode('--$boundary\r\n'));
          bodyBuilder.add(utf8.encode('Content-Disposition: form-data; name="file"; filename="$filename"\r\n'));
          bodyBuilder.add(utf8.encode('Content-Type: application/pdf\r\n\r\n'));
          bodyBuilder.add(fileBytes);
          bodyBuilder.add(utf8.encode('\r\n--$boundary--\r\n'));

          final fullBody = bodyBuilder.toBytes();

          print('Sending upload request (${fullBody.length} bytes)...');
          final res = await http.post(
            uploadUrl,
            headers: {
              'Content-Type': 'multipart/form-data; boundary=$boundary',
              'Content-Length': '${fullBody.length}',
            },
            body: fullBody,
          ).timeout(const Duration(seconds: 15));

          print('Upload Response Status: ${res.statusCode}');
          print('Upload Response Body: ${res.body}');
        }
      }
    } catch (e, st) {
      print('Error: $e');
      print('Stacktrace: $st');
    }
  });
}
