import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/core_providers.dart';
import '../auth/application/session_controller.dart';
import '../profile/domain/profile.dart';

/// People I've blocked. Enforcement lives in the database (RLS on messages and
/// calls, and search_users); this only drives the UI.
final blockedUsersProvider = AsyncNotifierProvider<BlockedUsersController, List<Profile>>(BlockedUsersController.new);

class BlockedUsersController extends AsyncNotifier<List<Profile>> {
  SupabaseClient get _client => ref.read(supabaseProvider);

  @override
  Future<List<Profile>> build() async {
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
    if (myId == null) return const [];
    final rows = await _client
        .from('blocks')
        .select('profile:profiles!blocks_blocked_id_fkey(*)')
        .eq('blocker_id', myId)
        .order('created_at', ascending: false);
    return [for (final r in rows) Profile.fromJson(r['profile'] as Map<String, dynamic>)];
  }

  bool isBlocked(String userId) => state.value?.any((p) => p.id == userId) ?? false;

  Future<void> block(Profile user) async {
    await _client.from('blocks').insert({'blocker_id': _client.auth.currentUser!.id, 'blocked_id': user.id});
    state = AsyncData([user, ...?state.value]);
  }

  Future<void> unblock(String userId) async {
    await _client.from('blocks').delete().eq('blocker_id', _client.auth.currentUser!.id).eq('blocked_id', userId);
    state = AsyncData([...?state.value?.where((p) => p.id != userId)]);
  }
}
