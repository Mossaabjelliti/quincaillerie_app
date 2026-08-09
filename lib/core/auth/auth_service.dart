import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';

class AuthService {
  final SupabaseClient supabase;

  AuthService({required this.supabase});

  User? get currentUser => supabase.auth.currentUser;
  Session? get currentSession => supabase.auth.currentSession;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
  bool get isAuthenticated => currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone ?? '',
        'role': UserRole.owner.wireValue,
      },
    );
    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Future-ready Phone Auth OTP request
  Future<void> sendPhoneOtp(String phone) async {
    await supabase.auth.signInWithOtp(
      phone: phone,
    );
  }

  /// Future-ready Phone Auth OTP verification
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return await supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }
}
