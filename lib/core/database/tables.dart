import 'package:drift/drift.dart';

// ─── Clipboard Entries Table ───
class ClipboardEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get dataType => text().withDefault(const Constant('TEXT'))();
  TextColumn get sourceDevice => text()();
  DateTimeColumn get timestamp => dateTime()();
}

// ─── Paired Devices Table ───
class PairedDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text().unique()();
  TextColumn get name => text()();
  TextColumn get platform => text()();
  TextColumn get certPem => text()();
  TextColumn get certFingerprint => text()();
  TextColumn get lastIp => text().nullable()();
  IntColumn get lastPort => integer().nullable()();
  DateTimeColumn get pairedAt => dateTime()();
}

// ─── Manual Devices Table (mDNS fallback) ───
class ManualDevices extends Table {
  IntColumn get id => integer().autoIncrement()();

}
