// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ClipboardEntriesTable extends ClipboardEntries
    with TableInfo<$ClipboardEntriesTable, ClipboardEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipboardEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataTypeMeta = const VerificationMeta(
    'dataType',
  );
  @override
  late final GeneratedColumn<String> dataType = GeneratedColumn<String>(
    'data_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TEXT'),
  );
  static const VerificationMeta _sourceDeviceMeta = const VerificationMeta(
    'sourceDevice',
  );
  @override
  late final GeneratedColumn<String> sourceDevice = GeneratedColumn<String>(
    'source_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    dataType,
    sourceDevice,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clipboard_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipboardEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('data_type')) {
      context.handle(
        _dataTypeMeta,
        dataType.isAcceptableOrUnknown(data['data_type']!, _dataTypeMeta),
      );
    }
    if (data.containsKey('source_device')) {
      context.handle(
        _sourceDeviceMeta,
        sourceDevice.isAcceptableOrUnknown(
          data['source_device']!,
          _sourceDeviceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceDeviceMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipboardEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipboardEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      dataType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_type'],
      )!,
      sourceDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $ClipboardEntriesTable createAlias(String alias) {
    return $ClipboardEntriesTable(attachedDatabase, alias);
  }
}

class ClipboardEntry extends DataClass implements Insertable<ClipboardEntry> {
  final int id;
  final String content;
  final String dataType;
  final String sourceDevice;
  final DateTime timestamp;
  const ClipboardEntry({
    required this.id,
    required this.content,
    required this.dataType,
    required this.sourceDevice,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['data_type'] = Variable<String>(dataType);
    map['source_device'] = Variable<String>(sourceDevice);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ClipboardEntriesCompanion toCompanion(bool nullToAbsent) {
    return ClipboardEntriesCompanion(
      id: Value(id),
      content: Value(content),
      dataType: Value(dataType),
      sourceDevice: Value(sourceDevice),
      timestamp: Value(timestamp),
    );
  }

  factory ClipboardEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipboardEntry(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      dataType: serializer.fromJson<String>(json['dataType']),
      sourceDevice: serializer.fromJson<String>(json['sourceDevice']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'dataType': serializer.toJson<String>(dataType),
      'sourceDevice': serializer.toJson<String>(sourceDevice),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  ClipboardEntry copyWith({
    int? id,
    String? content,
    String? dataType,
    String? sourceDevice,
    DateTime? timestamp,
  }) => ClipboardEntry(
    id: id ?? this.id,
    content: content ?? this.content,
    dataType: dataType ?? this.dataType,
    sourceDevice: sourceDevice ?? this.sourceDevice,
    timestamp: timestamp ?? this.timestamp,
  );
  ClipboardEntry copyWithCompanion(ClipboardEntriesCompanion data) {
    return ClipboardEntry(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      dataType: data.dataType.present ? data.dataType.value : this.dataType,
      sourceDevice: data.sourceDevice.present
          ? data.sourceDevice.value
          : this.sourceDevice,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipboardEntry(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('dataType: $dataType, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, content, dataType, sourceDevice, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipboardEntry &&
          other.id == this.id &&
          other.content == this.content &&
          other.dataType == this.dataType &&
          other.sourceDevice == this.sourceDevice &&
          other.timestamp == this.timestamp);
}

class ClipboardEntriesCompanion extends UpdateCompanion<ClipboardEntry> {
  final Value<int> id;
  final Value<String> content;
  final Value<String> dataType;
  final Value<String> sourceDevice;
  final Value<DateTime> timestamp;
  const ClipboardEntriesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.dataType = const Value.absent(),
    this.sourceDevice = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ClipboardEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    this.dataType = const Value.absent(),
    required String sourceDevice,
    required DateTime timestamp,
  }) : content = Value(content),
       sourceDevice = Value(sourceDevice),
       timestamp = Value(timestamp);
  static Insertable<ClipboardEntry> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<String>? dataType,
    Expression<String>? sourceDevice,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (dataType != null) 'data_type': dataType,
      if (sourceDevice != null) 'source_device': sourceDevice,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ClipboardEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<String>? dataType,
    Value<String>? sourceDevice,
    Value<DateTime>? timestamp,
  }) {
    return ClipboardEntriesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      dataType: dataType ?? this.dataType,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (dataType.present) {
      map['data_type'] = Variable<String>(dataType.value);
    }
    if (sourceDevice.present) {
      map['source_device'] = Variable<String>(sourceDevice.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipboardEntriesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('dataType: $dataType, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $PairedDevicesTable extends PairedDevices
    with TableInfo<$PairedDevicesTable, PairedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PairedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certPemMeta = const VerificationMeta(
    'certPem',
  );
  @override
  late final GeneratedColumn<String> certPem = GeneratedColumn<String>(
    'cert_pem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certFingerprintMeta = const VerificationMeta(
    'certFingerprint',
  );
  @override
  late final GeneratedColumn<String> certFingerprint = GeneratedColumn<String>(
    'cert_fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastIpMeta = const VerificationMeta('lastIp');
  @override
  late final GeneratedColumn<String> lastIp = GeneratedColumn<String>(
    'last_ip',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPortMeta = const VerificationMeta(
    'lastPort',
  );
  @override
  late final GeneratedColumn<int> lastPort = GeneratedColumn<int>(
    'last_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairedAtMeta = const VerificationMeta(
    'pairedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pairedAt = GeneratedColumn<DateTime>(
    'paired_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    name,
    platform,
    certPem,
    certFingerprint,
    lastIp,
    lastPort,
    pairedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paired_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<PairedDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('cert_pem')) {
      context.handle(
        _certPemMeta,
        certPem.isAcceptableOrUnknown(data['cert_pem']!, _certPemMeta),
      );
    } else if (isInserting) {
      context.missing(_certPemMeta);
    }
    if (data.containsKey('cert_fingerprint')) {
      context.handle(
        _certFingerprintMeta,
        certFingerprint.isAcceptableOrUnknown(
          data['cert_fingerprint']!,
          _certFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_certFingerprintMeta);
    }
    if (data.containsKey('last_ip')) {
      context.handle(
        _lastIpMeta,
        lastIp.isAcceptableOrUnknown(data['last_ip']!, _lastIpMeta),
      );
    }
    if (data.containsKey('last_port')) {
      context.handle(
        _lastPortMeta,
        lastPort.isAcceptableOrUnknown(data['last_port']!, _lastPortMeta),
      );
    }
    if (data.containsKey('paired_at')) {
      context.handle(
        _pairedAtMeta,
        pairedAt.isAcceptableOrUnknown(data['paired_at']!, _pairedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pairedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PairedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PairedDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      certPem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cert_pem'],
      )!,
      certFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cert_fingerprint'],
      )!,
      lastIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_ip'],
      ),
      lastPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_port'],
      ),
      pairedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paired_at'],
      )!,
    );
  }

  @override
  $PairedDevicesTable createAlias(String alias) {
    return $PairedDevicesTable(attachedDatabase, alias);
  }
}

class PairedDevice extends DataClass implements Insertable<PairedDevice> {
  final int id;
  final String deviceId;
  final String name;
  final String platform;
  final String certPem;
  final String certFingerprint;
  final String? lastIp;
  final int? lastPort;
  final DateTime pairedAt;
  const PairedDevice({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.certPem,
    required this.certFingerprint,
    this.lastIp,
    this.lastPort,
    required this.pairedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    map['platform'] = Variable<String>(platform);
    map['cert_pem'] = Variable<String>(certPem);
    map['cert_fingerprint'] = Variable<String>(certFingerprint);
    if (!nullToAbsent || lastIp != null) {
      map['last_ip'] = Variable<String>(lastIp);
    }
    if (!nullToAbsent || lastPort != null) {
      map['last_port'] = Variable<int>(lastPort);
    }
    map['paired_at'] = Variable<DateTime>(pairedAt);
    return map;
  }

  PairedDevicesCompanion toCompanion(bool nullToAbsent) {
    return PairedDevicesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      name: Value(name),
      platform: Value(platform),
      certPem: Value(certPem),
      certFingerprint: Value(certFingerprint),
      lastIp: lastIp == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIp),
      lastPort: lastPort == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPort),
      pairedAt: Value(pairedAt),
    );
  }

  factory PairedDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PairedDevice(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      platform: serializer.fromJson<String>(json['platform']),
      certPem: serializer.fromJson<String>(json['certPem']),
      certFingerprint: serializer.fromJson<String>(json['certFingerprint']),
      lastIp: serializer.fromJson<String?>(json['lastIp']),
      lastPort: serializer.fromJson<int?>(json['lastPort']),
      pairedAt: serializer.fromJson<DateTime>(json['pairedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'platform': serializer.toJson<String>(platform),
      'certPem': serializer.toJson<String>(certPem),
      'certFingerprint': serializer.toJson<String>(certFingerprint),
      'lastIp': serializer.toJson<String?>(lastIp),
      'lastPort': serializer.toJson<int?>(lastPort),
      'pairedAt': serializer.toJson<DateTime>(pairedAt),
    };
  }

  PairedDevice copyWith({
    int? id,
    String? deviceId,
    String? name,
    String? platform,
    String? certPem,
    String? certFingerprint,
    Value<String?> lastIp = const Value.absent(),
    Value<int?> lastPort = const Value.absent(),
    DateTime? pairedAt,
  }) => PairedDevice(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    platform: platform ?? this.platform,
    certPem: certPem ?? this.certPem,
    certFingerprint: certFingerprint ?? this.certFingerprint,
    lastIp: lastIp.present ? lastIp.value : this.lastIp,
    lastPort: lastPort.present ? lastPort.value : this.lastPort,
    pairedAt: pairedAt ?? this.pairedAt,
  );
  PairedDevice copyWithCompanion(PairedDevicesCompanion data) {
    return PairedDevice(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      platform: data.platform.present ? data.platform.value : this.platform,
      certPem: data.certPem.present ? data.certPem.value : this.certPem,
      certFingerprint: data.certFingerprint.present
          ? data.certFingerprint.value
          : this.certFingerprint,
      lastIp: data.lastIp.present ? data.lastIp.value : this.lastIp,
      lastPort: data.lastPort.present ? data.lastPort.value : this.lastPort,
      pairedAt: data.pairedAt.present ? data.pairedAt.value : this.pairedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PairedDevice(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('certPem: $certPem, ')
          ..write('certFingerprint: $certFingerprint, ')
          ..write('lastIp: $lastIp, ')
          ..write('lastPort: $lastPort, ')
          ..write('pairedAt: $pairedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    name,
    platform,
    certPem,
    certFingerprint,
    lastIp,
    lastPort,
    pairedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PairedDevice &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.platform == this.platform &&
          other.certPem == this.certPem &&
          other.certFingerprint == this.certFingerprint &&
          other.lastIp == this.lastIp &&
          other.lastPort == this.lastPort &&
          other.pairedAt == this.pairedAt);
}

class PairedDevicesCompanion extends UpdateCompanion<PairedDevice> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> name;
  final Value<String> platform;
  final Value<String> certPem;
  final Value<String> certFingerprint;
  final Value<String?> lastIp;
  final Value<int?> lastPort;
  final Value<DateTime> pairedAt;
  const PairedDevicesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.platform = const Value.absent(),
    this.certPem = const Value.absent(),
    this.certFingerprint = const Value.absent(),
    this.lastIp = const Value.absent(),
    this.lastPort = const Value.absent(),
    this.pairedAt = const Value.absent(),
  });
  PairedDevicesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    required String name,
    required String platform,
    required String certPem,
    required String certFingerprint,
    this.lastIp = const Value.absent(),
    this.lastPort = const Value.absent(),
    required DateTime pairedAt,
  }) : deviceId = Value(deviceId),
       name = Value(name),
       platform = Value(platform),
       certPem = Value(certPem),
       certFingerprint = Value(certFingerprint),
       pairedAt = Value(pairedAt);
  static Insertable<PairedDevice> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<String>? platform,
    Expression<String>? certPem,
    Expression<String>? certFingerprint,
    Expression<String>? lastIp,
    Expression<int>? lastPort,
    Expression<DateTime>? pairedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (platform != null) 'platform': platform,
      if (certPem != null) 'cert_pem': certPem,
      if (certFingerprint != null) 'cert_fingerprint': certFingerprint,
      if (lastIp != null) 'last_ip': lastIp,
      if (lastPort != null) 'last_port': lastPort,
      if (pairedAt != null) 'paired_at': pairedAt,
    });
  }

  PairedDevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<String>? name,
    Value<String>? platform,
    Value<String>? certPem,
    Value<String>? certFingerprint,
    Value<String?>? lastIp,
    Value<int?>? lastPort,
    Value<DateTime>? pairedAt,
  }) {
    return PairedDevicesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      certPem: certPem ?? this.certPem,
      certFingerprint: certFingerprint ?? this.certFingerprint,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (certPem.present) {
      map['cert_pem'] = Variable<String>(certPem.value);
    }
    if (certFingerprint.present) {
      map['cert_fingerprint'] = Variable<String>(certFingerprint.value);
    }
    if (lastIp.present) {
      map['last_ip'] = Variable<String>(lastIp.value);
    }
    if (lastPort.present) {
      map['last_port'] = Variable<int>(lastPort.value);
    }
    if (pairedAt.present) {
      map['paired_at'] = Variable<DateTime>(pairedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PairedDevicesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('platform: $platform, ')
          ..write('certPem: $certPem, ')
          ..write('certFingerprint: $certFingerprint, ')
          ..write('lastIp: $lastIp, ')
          ..write('lastPort: $lastPort, ')
          ..write('pairedAt: $pairedAt')
          ..write(')'))
        .toString();
  }
}

class $ManualDevicesTable extends ManualDevices
    with TableInfo<$ManualDevicesTable, ManualDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManualDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Unknown'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ip, port, name, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manual_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<ManualDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ManualDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManualDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ManualDevicesTable createAlias(String alias) {
    return $ManualDevicesTable(attachedDatabase, alias);
  }
}

class ManualDevice extends DataClass implements Insertable<ManualDevice> {
  final int id;
  final String ip;
  final int port;
  final String name;
  final DateTime addedAt;
  const ManualDevice({
    required this.id,
    required this.ip,
    required this.port,
    required this.name,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ip'] = Variable<String>(ip);
    map['port'] = Variable<int>(port);
    map['name'] = Variable<String>(name);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ManualDevicesCompanion toCompanion(bool nullToAbsent) {
    return ManualDevicesCompanion(
      id: Value(id),
      ip: Value(ip),
      port: Value(port),
      name: Value(name),
      addedAt: Value(addedAt),
    );
  }

  factory ManualDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManualDevice(
      id: serializer.fromJson<int>(json['id']),
      ip: serializer.fromJson<String>(json['ip']),
      port: serializer.fromJson<int>(json['port']),
      name: serializer.fromJson<String>(json['name']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ip': serializer.toJson<String>(ip),
      'port': serializer.toJson<int>(port),
      'name': serializer.toJson<String>(name),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  ManualDevice copyWith({
    int? id,
    String? ip,
    int? port,
    String? name,
    DateTime? addedAt,
  }) => ManualDevice(
    id: id ?? this.id,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    name: name ?? this.name,
    addedAt: addedAt ?? this.addedAt,
  );
  ManualDevice copyWithCompanion(ManualDevicesCompanion data) {
    return ManualDevice(
      id: data.id.present ? data.id.value : this.id,
      ip: data.ip.present ? data.ip.value : this.ip,
      port: data.port.present ? data.port.value : this.port,
      name: data.name.present ? data.name.value : this.name,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManualDevice(')
          ..write('id: $id, ')
          ..write('ip: $ip, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ip, port, name, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManualDevice &&
          other.id == this.id &&
          other.ip == this.ip &&
          other.port == this.port &&
          other.name == this.name &&
          other.addedAt == this.addedAt);
}

class ManualDevicesCompanion extends UpdateCompanion<ManualDevice> {
  final Value<int> id;
  final Value<String> ip;
  final Value<int> port;
  final Value<String> name;
  final Value<DateTime> addedAt;
  const ManualDevicesCompanion({
    this.id = const Value.absent(),
    this.ip = const Value.absent(),
    this.port = const Value.absent(),
    this.name = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ManualDevicesCompanion.insert({
    this.id = const Value.absent(),
    required String ip,
    required int port,
    this.name = const Value.absent(),
    required DateTime addedAt,
  }) : ip = Value(ip),
       port = Value(port),
       addedAt = Value(addedAt);
  static Insertable<ManualDevice> custom({
    Expression<int>? id,
    Expression<String>? ip,
    Expression<int>? port,
    Expression<String>? name,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ip != null) 'ip': ip,
      if (port != null) 'port': port,
      if (name != null) 'name': name,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ManualDevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? ip,
    Value<int>? port,
    Value<String>? name,
    Value<DateTime>? addedAt,
  }) {
    return ManualDevicesCompanion(
      id: id ?? this.id,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      name: name ?? this.name,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManualDevicesCompanion(')
          ..write('id: $id, ')
          ..write('ip: $ip, ')
          ..write('port: $port, ')
          ..write('name: $name, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationHistoryTable extends NotificationHistory
    with TableInfo<$NotificationHistoryTable, NotificationHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _appNameMeta = const VerificationMeta(
    'appName',
  );
  @override
  late final GeneratedColumn<String> appName = GeneratedColumn<String>(
    'app_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageNameMeta = const VerificationMeta(
    'packageName',
  );
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
    'package_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconB64Meta = const VerificationMeta(
    'iconB64',
  );
  @override
  late final GeneratedColumn<String> iconB64 = GeneratedColumn<String>(
    'icon_b64',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasReplyActionMeta = const VerificationMeta(
    'hasReplyAction',
  );
  @override
  late final GeneratedColumn<bool> hasReplyAction = GeneratedColumn<bool>(
    'has_reply_action',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_reply_action" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notificationKeyMeta = const VerificationMeta(
    'notificationKey',
  );
  @override
  late final GeneratedColumn<String> notificationKey = GeneratedColumn<String>(
    'notification_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    appName,
    packageName,
    title,
    body,
    timestamp,
    iconB64,
    hasReplyAction,
    notificationKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_history';

}
