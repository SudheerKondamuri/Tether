import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:tether/shared/constants.dart';
import 'package:tether/shared/platform_utils.dart';
import 'package:tether/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  ClipboardEntries,
  PairedDevices,
  ManualDevices,
  Settings,
  NotificationHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  static bool isBackground = false;

  @override
  int get schemaVersion => 1;

  // ─── Clipboard Operations ───

  Future<List<ClipboardEntry>> getClipboardEntries() {
    return (select(clipboardEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(TetherConstants.clipboardMaxHistory))
        .get();
  }

  Stream<List<ClipboardEntry>> watchClipboardEntries() {
    return (select(clipboardEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(TetherConstants.clipboardMaxHistory))
        .watch();
  }

  Future<int> insertClipboardEntry(ClipboardEntriesCompanion entry) async {
    final id = await into(clipboardEntries).insert(entry);
    await _enforceClipboardLimit();
    return id;
  }

  Future<void> _enforceClipboardLimit() async {
    final count = await (selectOnly(clipboardEntries)
          ..addColumns([clipboardEntries.id.count()]))
        .getSingle();
    final total = count.read(clipboardEntries.id.count()) ?? 0;

    if (total > TetherConstants.clipboardMaxHistory) {
      final excess = total - TetherConstants.clipboardMaxHistory;
      final oldest = await (select(clipboardEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
            ..limit(excess))
          .get();
      for (final entry in oldest) {
        await (delete(clipboardEntries)
              ..where((t) => t.id.equals(entry.id)))
            .go();
      }
    }
  }

  Future<int> deleteClipboardEntry(int id) {
    return (delete(clipboardEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<int> clearClipboardEntries() {
    return delete(clipboardEntries).go();
  }

  // ─── Paired Devices Operations ───

  Future<List<PairedDevice>> getPairedDevices() {
    return select(pairedDevices).get();
  }

  Stream<List<PairedDevice>> watchPairedDevices() {
    return select(pairedDevices).watch();
  }

  Future<PairedDevice?> getPairedDeviceById(String deviceId) {
    return (select(pairedDevices)
          ..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  Future<int> upsertPairedDevice(PairedDevicesCompanion device) {
    return into(pairedDevices).insertOnConflictUpdate(device);
  }

  Future<int> deletePairedDevice(String deviceId) {
    return (delete(pairedDevices)
          ..where((t) => t.deviceId.equals(deviceId)))
        .go();
  }

  // ─── Manual Devices Operations ───

  Future<List<ManualDevice>> getManualDevices() {
    return select(manualDevices).get();
  }

  Stream<List<ManualDevice>> watchManualDevices() {
    return select(manualDevices).watch();
  }

  Future<int> insertManualDevice(ManualDevicesCompanion device) {
    return into(manualDevices).insert(device);
  }

  Future<int> deleteManualDevice(int id) {
    return (delete(manualDevices)..where((t) => t.id.equals(id))).go();
  }

  // ─── Settings Operations ───

  Future<String?> getSetting(String key) async {
    final result = await (select(settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Stream<String?> watchSetting(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  Future<bool> getSettingBool(String key, {bool defaultValue = false}) async {
    final val = await getSetting(key);
    if (val == null) return defaultValue;
    return val == 'true';
  }

  Future<void> setSettingBool(String key, bool value) {
    return setSetting(key, value.toString());
  }

  // ─── Notification History Operations ───

  Future<List<NotificationHistoryData>> getNotifications({int limit = 50}) {
    return (select(notificationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  Stream<List<NotificationHistoryData>> watchNotifications({int limit = 50}) {
    return (select(notificationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  Future<int> insertNotification(NotificationHistoryCompanion notif) {
    return into(notificationHistory).insert(notif);
  }

  Future<int> deleteNotification(int id) {
    return (delete(notificationHistory)..where((t) => t.id.equals(id))).go();
  }

  Future<int> clearNotifications() {
    return delete(notificationHistory).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, TetherConstants.databaseName));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA synchronous=NORMAL;');
      },
    );
  });
}

void initDatabaseSync(AppDatabase db) {
  if (!PlatformUtils.isAndroid) return;

  const channel = MethodChannel('com.tether/db_sync');
  bool isApplyingExternalUpdate = false;

  // Listen for table updates from other isolate
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onTableUpdate') {
      final List<dynamic>? tables = call.arguments['tables'];
      if (tables != null) {
        final tableInfos = db.allTables
            .where((t) => tables.contains(t.actualTableName))
            .toSet();
        if (tableInfos.isNotEmpty) {
          isApplyingExternalUpdate = true;
          try {
            db.notifyUpdates(
                tableInfos.map((t) => TableUpdate.onTable(t)).toSet());
          } catch (_) {
            // Ignore/Suppress
          } finally {
            isApplyingExternalUpdate = false;
          }
        }
      }
    }
  });

  // Listen to local updates and broadcast them
  db.tableUpdates(const TableUpdateQuery.any()).listen((updates) {
    if (isApplyingExternalUpdate) return;
    final tables = updates.map((u) => u.table).toList();
    if (tables.isNotEmpty) {
      channel.invokeMethod('notifyTableUpdate', {
        'tables': tables,
      });
    }
  });
}
