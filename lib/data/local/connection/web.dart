import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDatabase() {
  return LazyDatabase(() async {
    return WebDatabase('quincaillerie');
  });
}
