import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final profileRes = await authService.supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final membersRes = await authService.supabase
          .from('store_members')
          .select('id, store_id, user_id, role, created_at, stores:stores(id, name, address, phone, owner_id, created_at)')
          .eq('user_id', userId);

      final fullName = profileRes?['full_name'] as String? ?? email.split('@').first;
      final phone = profileRes?['phone'] as String? ?? '';
      final profileRole = profileRes?['role'] as String?;

      List<Store> loadedStores = [];
      final storeRoles = <String, String>{};
      String? activeStoreId;
      String? activeStoreName;
      String activeRole = profileRole ?? 'cashier';

      if (membersRes != null && (membersRes as List).isNotEmpty) {
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
            final role = m['role'] as String? ?? 'cashier';
            storeRoles[st.id] = role;
            await db.into(db.stores).insertOnConflictUpdate(st);
            await db.into(db.storeMembers).insertOnConflictUpdate(
                  StoreMembersCompanion.insert(
                    id: m['id']?.toString() ?? const Uuid().v4(),
                    storeId: st.id,
                    userId: userId,
                    role: Value(role),
                    synced: const Value(true),
                  ),
                );
          }
        }
      }

      final localMembers = await (db.select(db.storeMembers)..where((m) => m.userId.equals(userId))).get();
      final localStores = await db.select(db.stores).get();
      for (final member in localMembers) {
        storeRoles[member.storeId] = member.role;
      }
      for (final ls in localStores.where((store) => storeRoles.containsKey(store.id))) {
        if (!loadedStores.any((s) => s.id == ls.id)) {
          loadedStores.add(ls);
        }
      }

      if (loadedStores.isNotEmpty && storeRoles.isNotEmpty) {
        final preferredStore = loadedStores.firstWhere(
          (store) => storeRoles.containsKey(store.id),
          orElse: () => loadedStores.first,
        );
        activeStoreId = preferredStore.id;
        activeStoreName = preferredStore.name;
        activeRole = storeRoles[preferredStore.id] ?? activeRole;
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
        storeRoles: storeRoles,
      );

      await db.into(db.profiles).insertOnConflictUpdate(
            ProfilesCompanion.insert(
              id: userId,
              fullName: Value(fullName),
              phone: Value(phone),
              role: Value(profileRole ?? activeRole),
              synced: const Value(true),
            ),
          );
    } catch (e) {
      final localProfiles = await (db.select(db.profiles)..where((p) => p.id.equals(userId))).get();
      final localMembers = await (db.select(db.storeMembers)..where((m) => m.userId.equals(userId))).get();
      final localRoles = {for (final member in localMembers) member.storeId: member.role};
      final localStores = (await db.select(db.stores).get())
          .where((store) => localRoles.containsKey(store.id))
          .toList();

      _session = UserSession(
        userId: userId,
        userEmail: email,
        fullName: localProfiles.isNotEmpty ? localProfiles.first.fullName : email.split('@').first,
        phone: localProfiles.isNotEmpty ? localProfiles.first.phone : '',
        currentStoreId: localStores.isNotEmpty && localRoles.isNotEmpty ? localStores.first.id : null,
        currentStoreName: localStores.isNotEmpty && localRoles.isNotEmpty ? localStores.first.name : null,
        currentRole: localProfiles.isNotEmpty ? localProfiles.first.role : 'cashier',
        stores: localStores,
        storeRoles: localRoles,
      );
      _status = (_session?.hasActiveStore == true) ? AuthStatus.authenticated : AuthStatus.noStore;
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
        return _status == AuthStatus.authenticated || _status == AuthStatus.noStore;
      }
    } on AuthException catch (e) {
      if (e.message.contains('Email not confirmed')) {
        _errorMessage = 'Veuillez confirmer votre e-mail en cliquant sur le lien reçu dans votre boîte de réception ($email) avant de vous connecter.';
      } else {
        _errorMessage = 'Échec de connexion: ${e.message}';
      }
      _status = AuthStatus.error;
      notifyListeners();
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
        // Create initial store locally & on remote if session active
        await createStore(
          name: storeName,
          ownerId: res.user!.id,
          userFullName: fullName,
          userEmail: email,
        );

        if (res.session == null) {
          // Email confirmation is required by Supabase project
          _errorMessage = 'Compte créé avec succès ! Un e-mail de confirmation vous a été envoyé à $email. Veuillez vérifier votre boîte de réception.';
          _status = AuthStatus.error;
          notifyListeners();
          return false;
        }

        return true;
      }
    } on AuthException catch (e) {
      _errorMessage = 'Échec d\'inscription: ${e.message}';
      _status = AuthStatus.error;
      notifyListeners();
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
    } catch (e) {
      // The local rows remain unsynced and will be retried by the sync engine.
      debugPrint('Store creation will be synced later: $e');
    }

    await _loadUserSession(uid, userEmail ?? _session?.userEmail ?? '');
    notifyListeners();
    return true;
  }

  void selectStore(String storeId) {
    if (_session == null) return;
    final target = _session!.stores.firstWhere((s) => s.id == storeId, orElse: () => _session!.stores.first);
    final role = _session!.roleForStore(target.id);
    _session = _session!.copyWith(
      currentStoreId: target.id,
      currentStoreName: target.name,
      currentRole: role,
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
