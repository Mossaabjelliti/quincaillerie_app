import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import 'auth_service.dart';
import 'user_session.dart';

enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  noStore,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final AppDatabase db;

  AuthStatus _status = AuthStatus.uninitialized;
  UserSession? _session;
  String? _errorMessage;

  AuthProvider({required this.authService, required this.db}) {
    _init();
  }

  AuthStatus get status => _status;
  UserSession? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _session?.hasActiveStore == true;

  Future<void> _init() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      final user = authService.currentUser;
      if (user != null) {
        await _loadUserSession(user.id, user.email ?? '');
      } else {
        _status = AuthStatus.uninitialized;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadUserSession(String userId, String email) async {
    try {
      // 1. Try to load from Supabase remote first
      final profileRes = await authService.supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final membersRes = await authService.supabase
          .from('store_members')
          .select('*, stores(*)')
          .eq('user_id', userId);

      final fullName = profileRes?['full_name'] as String? ?? 'Utilisateur';
      final phone = profileRes?['phone'] as String? ?? '';
      final defaultRole = profileRes?['role'] as String? ?? 'owner';

      List<Store> loadedStores = [];
      String? activeStoreId;
      String? activeStoreName;
      String activeRole = defaultRole;

      if ((membersRes as List).isNotEmpty) {
        for (final m in membersRes) {
          final sData = m['stores'];
          if (sData != null) {
            final st = Store(
              id: sData['id'],
              name: sData['name'],
              address: sData['address'] ?? '',
              phone: sData['phone'] ?? '',
              ownerId: sData['owner_id'],
              createdAt: DateTime.tryParse(sData['created_at'] ?? '') ?? DateTime.now(),
              synced: true,
            );
            loadedStores.add(st);

            // Save store locally to SQLite for offline access
            await db.into(db.stores).insertOnConflictUpdate(st);
          }
        }
      }

      if (loadedStores.isNotEmpty) {
        activeStoreId = loadedStores.first.id;
        activeStoreName = loadedStores.first.name;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.noStore;
      }

      _session = UserSession(
        userId: userId,
        userEmail: email,
        fullName: fullName,
        phone: phone,
        currentStoreId: activeStoreId,
        currentStoreName: activeStoreName,
        currentRole: activeRole,
        stores: loadedStores,
      );

      // Save profile locally
      await db.into(db.profiles).insertOnConflictUpdate(
            ProfilesCompanion.insert(
              id: userId,
              fullName: Value(fullName),
              phone: Value(phone),
              role: Value(defaultRole),
              synced: const Value(true),
            ),
          );
    } catch (e) {
      // Offline fallback: load from local SQLite Drift database
      final localProfiles = await (db.select(db.profiles)..where((p) => p.id.equals(userId))).get();
      final localStores = await db.select(db.stores).get();

      if (localProfiles.isNotEmpty) {
        final prof = localProfiles.first;
        _session = UserSession(
          userId: userId,
          userEmail: email,
          fullName: prof.fullName,
          phone: prof.phone,
          currentStoreId: localStores.isNotEmpty ? localStores.first.id : null,
          currentStoreName: localStores.isNotEmpty ? localStores.first.name : null,
          currentRole: prof.role,
          stores: localStores,
        );
        _status = localStores.isNotEmpty ? AuthStatus.authenticated : AuthStatus.noStore;
      } else {
        _status = AuthStatus.error;
        _errorMessage = 'Connexion requise pour la première utilisation.';
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await authService.signInWithEmail(email: email, password: password);
      if (res.user != null) {
        await _loadUserSession(res.user!.id, res.user!.email ?? email);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Échec de connexion: ${e.toString()}';
      _status = AuthStatus.error;
      notifyListeners();
    }
    return false;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String storeName,
    String? phone,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      if (res.user != null) {
        // Create initial store for owner
        await createStore(
          name: storeName,
          ownerId: res.user!.id,
          userFullName: fullName,
          userEmail: email,
        );
        return true;
      }
    } catch (e) {
      _errorMessage = 'Échec d\'inscription: ${e.toString()}';
      _status = AuthStatus.error;
      notifyListeners();
    }
    return false;
  }

  Future<bool> createStore({
    required String name,
    String? ownerId,
    String? address,
    String? phone,
    String? userFullName,
    String? userEmail,
  }) async {
    const uuid = Uuid();
    final storeId = uuid.v4();
    final uid = ownerId ?? _session?.userId ?? '';
    final now = DateTime.now();

    final newStore = Store(
      id: storeId,
      name: name,
      address: address ?? '',
      phone: phone ?? '',
      ownerId: uid,
      createdAt: now,
      synced: false,
    );

    // Save locally
    await db.into(db.stores).insertOnConflictUpdate(newStore);
    await db.into(db.storeMembers).insertOnConflictUpdate(
          StoreMembersCompanion.insert(
            id: uuid.v4(),
            storeId: storeId,
            userId: uid,
            role: const Value('owner'),
            synced: const Value(false),
          ),
        );

    // Sync to Supabase if connected
    try {
      await authService.supabase.from('stores').insert({
        'id': storeId,
        'name': name,
        'address': address ?? '',
        'phone': phone ?? '',
        'owner_id': uid,
      });

      await authService.supabase.from('store_members').insert({
        'id': uuid.v4(),
        'store_id': storeId,
        'user_id': uid,
        'role': 'owner',
      });
    } catch (_) {
      // Offline: local row flagged synced=false will be pushed by SyncManager
    }

    await _loadUserSession(uid, userEmail ?? _session?.userEmail ?? '');
    notifyListeners();
    return true;
  }

  void selectStore(String storeId) {
    if (_session == null) return;
    final target = _session!.stores.firstWhere((s) => s.id == storeId, orElse: () => _session!.stores.first);
    _session = _session!.copyWith(
      currentStoreId: target.id,
      currentStoreName: target.name,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await authService.signOut();
    _session = null;
    _status = AuthStatus.uninitialized;
    notifyListeners();
  }
}
