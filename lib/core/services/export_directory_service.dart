import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExportCategory {
  attendance('Attendance'),
  orders('Orders'),
  finance('Finance'),
  employees('Employees'),
  passes('Passes'),
  general('General');

  final String folderName;
  const ExportCategory(this.folderName);
}

class ExportDirectoryService {
  static const String _prefExportDirKey = 'export_destination_directory';
  static const String _prefAutoArrangeKey = 'auto_arrange_export_folders';

  /// Resolves the destination directory for saving an export file based on user settings
  /// and the target category.
  static Future<Directory> resolveExportDirectory({
    ExportCategory category = ExportCategory.general,
    String? customPath,
    bool? autoArrange,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = customPath ?? prefs.getString(_prefExportDirKey);
    final isAutoArrange = autoArrange ?? (prefs.getBool(_prefAutoArrangeKey) ?? true);

    Directory baseDir;
    if (savedPath != null && savedPath.trim().isNotEmpty) {
      baseDir = Directory(savedPath.trim());
    } else {
      // Default fallback
      if (!kIsWeb) {
        try {
          if (Platform.isMacOS) {
            // On macOS Sandbox, ApplicationDocuments is guaranteed writable
            baseDir = await getApplicationDocumentsDirectory();
          } else if (Platform.isWindows || Platform.isLinux) {
            baseDir = (await getDownloadsDirectory()) ?? (await getApplicationDocumentsDirectory());
          } else {
            baseDir = (await getApplicationDocumentsDirectory());
          }
        } catch (_) {
          baseDir = Directory.systemTemp;
        }
      } else {
        baseDir = Directory.systemTemp;
      }
    }

    if (!await baseDir.exists()) {
      try {
        await baseDir.create(recursive: true);
      } catch (_) {
        baseDir = await getApplicationDocumentsDirectory();
        if (!await baseDir.exists()) {
          await baseDir.create(recursive: true);
        }
      }
    }

    // Auto-arrange in category subfolder if enabled
    if (isAutoArrange) {
      final categoryDir = Directory('${baseDir.path}/${category.folderName}');
      if (!await categoryDir.exists()) {
        try {
          await categoryDir.create(recursive: true);
          return categoryDir;
        } catch (_) {
          return baseDir;
        }
      }
      return categoryDir;
    }

    return baseDir;
  }

  /// Automatically deduces the ExportCategory from the filename or title.
  static ExportCategory deduceCategory(String filenameOrTitle) {
    final lower = filenameOrTitle.toLowerCase();
    if (lower.contains('attend') || lower.contains('shift') || lower.contains('clock')) {
      return ExportCategory.attendance;
    }
    if (lower.contains('order') || lower.contains('invoice') || lower.contains('item')) {
      return ExportCategory.orders;
    }
    if (lower.contains('finance') || lower.contains('expense') || lower.contains('statement') || lower.contains('profit') || lower.contains('revenue')) {
      return ExportCategory.finance;
    }
    if (lower.contains('employee') || lower.contains('staff') || lower.contains('profile') || lower.contains('dossier') || lower.contains('hr')) {
      return ExportCategory.employees;
    }
    if (lower.contains('pass') || lower.contains('ticket') || lower.contains('badge')) {
      return ExportCategory.passes;
    }
    return ExportCategory.general;
  }

  /// Opens the directory in the OS file explorer (Finder on macOS, File Explorer on Windows, xdg-open on Linux).
  static Future<bool> openDirectory(String directoryPath) async {
    if (kIsWeb) return false;
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return false;

    try {
      if (Platform.isMacOS) {
        final res = await Process.run('open', [dir.path]);
        return res.exitCode == 0;
      } else if (Platform.isWindows) {
        final res = await Process.run('explorer.exe', [dir.path]);
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final res = await Process.run('xdg-open', [dir.path]);
        return res.exitCode == 0;
      }
    } catch (e) {
      debugPrint('ExportDirectoryService: Failed to open directory: $e');
    }
    return false;
  }
}
