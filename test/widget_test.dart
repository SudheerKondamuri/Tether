import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/providers.dart';
import 'package:tether/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create an in-memory database for testing
    final testDb = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const TetherApp(),
      ),
    );
    expect(find.byType(TetherApp), findsOneWidget);

    // Clean up
    await testDb.close();
  });
}
