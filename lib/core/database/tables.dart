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
  TextColumn get ip => text()();
  IntColumn get port => integer()();
  TextColumn get name => text().withDefault(const Constant('Unknown'))();
  DateTimeColumn get addedAt => dateTime()();
}

// ─── Settings Table (key-value store) ───
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── Notification History Table ───
class NotificationHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get appName => text()();
  TextColumn get packageName => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get iconB64 => text().nullable()();
  BoolColumn get hasReplyAction => boolean().withDefault(const Constant(false))();
  TextColumn get notificationKey => text().nullable()();
}
