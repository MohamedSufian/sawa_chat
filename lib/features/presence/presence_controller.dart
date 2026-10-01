import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/core_providers.dart';
import '../auth/application/session_controller.dart';

/// Ids of users that currently have the app open, via Realtime Presence.
///
/// While the app is visible this device joins the shared `online` channel and
/// refreshes `last_seen_at` every minute; when hidden it leaves and stamps
/// `last_seen_at` one final time. If the app is killed, Presence drops the user
/// after its timeout and `last_seen_at` is at most a minute stale.
final presenceProvider = NotifierProvider<PresenceController, Set<String>>(PresenceController.new);

class PresenceController extends Notifier<Set<String>> {
  static const _heartbeatInterval = Duration(minutes: 1);

  RealtimeChannel? _channel;
  Timer? _heartbeat;
  bool _visible = true;

  SupabaseClient get _client => ref.read(supabaseProvider);

  @override
  Set<String> build() {
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
    if (myId == null) return const {};

    final channel = _client.channel('online', opts: RealtimeChannelConfig(key: myId));
    _channel = channel;
    channel
        .onPresenceSync((_) {
          state = {for (final entry in channel.presenceState()) entry.key};
        })
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed && _visible) _goOnline();
        });

    final lifecycle = AppLifecycleListener(
      onShow: () {
        _visible = true;
        _goOnline();
      },
      onHide: () {
        _visible = false;
        _goOffline();
      },
    );

    ref.onDispose(() {
      lifecycle.dispose();
      _heartbeat?.cancel();
      _touchLastSeen();
      _client.removeChannel(channel);
      _channel = null;
    });
    return const {};
  }

  void _goOnline() {
    _channel?.track({'online_at': DateTime.now().toUtc().toIso8601String()}).ignore();
    _touchLastSeen();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _touchLastSeen());
  }

  void _goOffline() {
    _heartbeat?.cancel();
    _channel?.untrack().ignore();
    _touchLastSeen();
  }

  void _touchLastSeen() {
    if (_client.auth.currentUser == null) return;
    _client.rpc<void>('touch_last_seen').then((_) {}, onError: (_) {});
  }
}
