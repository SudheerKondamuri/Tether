import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';

/// Singleton database instance provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
