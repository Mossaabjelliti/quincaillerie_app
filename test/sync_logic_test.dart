import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sync Queue Serialization & Status Tests', () {
    test('Identifies unsynced rows for push operation', () {
      final rows = [
        {'id': '1', 'synced': false},
        {'id': '2', 'synced': true},
        {'id': '3', 'synced': false},
      ];

      final unsynced = rows.where((r) => r['synced'] == false).toList();
      expect(unsynced.length, equals(2));
      expect(unsynced.map((r) => r['id']), containsAll(['1', '3']));
    });
  });
}
