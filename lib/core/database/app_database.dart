import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tether/shared/constants.dart';
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
  /// Set by `main.dart` (Flutter) before constructing `AppDatabase()`.
  /// Unused by `AppDatabase.atPath()` which takes the path directly.
  static String? dbPathOverride;

  /// Direct constructor for single-process use (Linux desktop / Flutter app).
  AppDatabase() : super(_openConnection());

  /// Explicit-path constructor for daemon use (no path_provider needed).
  /// The daemon knows its own data dir and passes the full DB path.
  AppDatabase.atPath(String dbPath)
      : super(NativeDatabase(
          File(dbPath),
          logStatements: false,
          setup: (rawDb) {
            rawDb.execute('PRAGMA journal_mode=WAL;');
            rawDb.execute('PRAGMA synchronous=NORMAL;');
          },
        ));

  /// Constructor for DriftIsolate client connections (Android multi-isolate).
  /// DatabaseConnection extends QueryExecutor, so it passes directly to super.
  AppDatabase.connect(super.connection);

  /// Testing constructor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // NOTE: openShared() was removed during daemon decoupling.
  // It relied on dart:ui's IsolateNameServer and path_provider.
  // Android uses direct NativeDatabase; Linux daemon uses AppDatabase.atPath().

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

/// Direct NativeDatabase connection for single-process desktop use.
/// The DB path must be set via [AppDatabase.dbPathOverride] before
/// constructing an `AppDatabase()` (the Flutter app does this in main.dart).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbPath = AppDatabase.dbPathOverride;
    if (dbPath == null) {
      throw StateError(
        'AppDatabase.dbPathOverride must be set before constructing '
        'AppDatabase(). Call it in main.dart after resolving the data dir.',
      );
    }
    final file = File(dbPath);
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA synchronous=NORMAL;');
      },
    );
  });
}
