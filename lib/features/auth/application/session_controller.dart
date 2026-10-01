import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';

enum SessionStatus { loading, signedOut, needsProfile, ready, error }

class SessionState {
  const SessionState(this.status, {this.profile});

  final SessionStatus status;
  final Profile? profile;
}

/// Single source of truth for "who is signed in and have they finished onboarding".
/// The router redirects purely from this state.
final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  String? _resolvedUserId;

  @override
  SessionState build() {
    final auth = ref.watch(supabaseProvider).auth;
    final sub = auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.tokenRefreshed) return;
      _resolve(data.session?.user);
    });
    ref.onDispose(sub.cancel);
    return const SessionState(SessionStatus.loading);
  }

  Future<void> _resolve(User? user) async {
    if (user == null) {
      _resolvedUserId = null;
      state = const SessionState(SessionStatus.signedOut);
      return;
    }
    if (user.id == _resolvedUserId && state.status == SessionStatus.ready) return;

    state = const SessionState(SessionStatus.loading);
    try {
      final profile = await ref.read(profileRepositoryProvider).fetch(user.id);
      _resolvedUserId = user.id;
      state = profile == null
          ? const SessionState(SessionStatus.needsProfile)
          : SessionState(SessionStatus.ready, profile: profile);
    } catch (_) {
      state = const SessionState(SessionStatus.error);
    }
  }

  Future<void> retry() => _resolve(ref.read(supabaseProvider).auth.currentUser);

  void profileCreated(Profile profile) {
    _resolvedUserId = profile.id;
    state = SessionState(SessionStatus.ready, profile: profile);
  }
}
