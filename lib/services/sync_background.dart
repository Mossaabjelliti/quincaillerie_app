import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import '../data/local/database.dart';
import 'sync_service.dart';

const dailySyncTask = 'dailySyncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().executeTask((task, inputData) async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );

    final db = AppDatabase();
    final service = SyncService(db: db, supabase: Supabase.instance.client);

    try {
      if (task == dailySyncTask) {
        await service.syncNow();
      }
    } finally {
      await db.close();
    }

    return Future.value(true);
  });
}
