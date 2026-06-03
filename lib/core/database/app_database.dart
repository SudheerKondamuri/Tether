import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

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


}
