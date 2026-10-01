import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider).auth));

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// [phone] must be in E.164 format, e.g. `+970599123456`.
  Future<void> sendOtp(String phone) => _auth.signInWithOtp(phone: phone);

  Future<void> verifyOtp({required String phone, required String code}) =>
      _auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  Future<void> signOut() => _auth.signOut();
}
