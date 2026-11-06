// services/backup_service.dart - 备份文件(导出/导入/每日快照)
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

class BackupService {
  final StorageService storage;

  BackupService(this.storage);

  static const int maxSnapshots = 14;
  static const String _prefix = 'backup_';

  Future<Directory> _backupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _stamp(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  /// 立即生成一个备份文件, 返回文件路径
  Future<String> createBackup() async {
    final dir = await _backupDir();
    final now = DateTime.now();
    final file = File('${dir.path}/$_prefix${_stamp(now)}.json');
    await file.writeAsString(storage.exportBackup());
    await _prune();
    return file.path;
  }

  /// 今日是否已有自动快照
  Future<bool> hasSnapshotToday() async {
    final dir = await _backupDir();
    final today = _stamp(DateTime.now()).substring(0, 8);
    return dir
        .listSync()
        .whereType<File>()
        .any((f) => f.path.split('/').last.startsWith('$_prefix$today'));
  }

  /// 每天首次打开时自动快照
  Future<String?> autoSnapshotIfNeeded() async {
    if (await hasSnapshotToday()) return null;
    return createBackup();
  }

  Future<List<String>> listBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files.map((f) => f.path).toList();
  }

  Future<String?> latestBackupPath() async {
    final list = await listBackups();
    return list.isEmpty ? null : list.first;
  }

  /// 读取备份内容用于恢复
  Future<String> readBackup(String path) => File(path).readAsString();

  Future<void> _prune() async {
    final list = await listBackups();
    for (final path in list.skip(maxSnapshots)) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}
