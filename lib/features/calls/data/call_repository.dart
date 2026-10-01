import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';
import '../domain/call.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) => CallRepository(ref.watch(supabaseProvider)));

class CallRepository {
  CallRepository(this._client);

  final SupabaseClient _client;

  String get myId => _client.auth.currentUser!.id;

  /// Creates the call row; it comes back as `busy` if the callee is already on a call.
  Future<CallRecord> start(String calleeId, {required bool video}) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'start_call',
      params: {'p_callee': calleeId, 'p_kind': video ? 'video' : 'audio'},
    );
    return CallRecord.fromJson(row);
  }

  Future<void> setStatus(String callId, CallStatus status) =>
      _client.rpc<void>('update_call_status', params: {'p_call_id': callId, 'p_status': status.name});

  Future<CallRecord?> fetch(String callId) async {
    final row = await _client.from('calls').select().eq('id', callId).maybeSingle();
    return row == null ? null : CallRecord.fromJson(row);
  }

  Future<List<CallRecord>> history({int limit = 100}) async {
    final rows = await _client
        .from('calls')
        .select('*, caller:profiles!calls_caller_id_fkey(*), callee:profiles!calls_callee_id_fkey(*)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(CallRecord.fromJson).toList();
  }

  /// Status changes of one call (accepted, declined, ended…).
  RealtimeChannel watch(String callId, void Function(CallRecord) onChange) => _client
      .channel('call-row:$callId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'calls',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: callId),
        callback: (p) => onChange(CallRecord.fromJson(p.newRecord)),
      )
      .subscribe();

  /// New calls where I'm the callee, while the app is open.
  RealtimeChannel watchIncoming(void Function(CallRecord) onIncoming) => _client
      .channel('incoming-calls:$myId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'calls',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'callee_id', value: myId),
        callback: (p) => onIncoming(CallRecord.fromJson(p.newRecord)),
      )
      .subscribe();

  /// Any change to my calls, for refreshing the history list.
  RealtimeChannel watchAll(void Function() onChange) => _client
      .channel('call-history:$myId')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'calls', callback: (_) => onChange())
      .subscribe();

  /// WebRTC signaling (offer / answer / ICE / hangup) over Realtime Broadcast.
  RealtimeChannel signaling(
    String callId, {
    required void Function(Map<String, dynamic> signal) onSignal,
    required void Function() onJoined,
  }) => _client
      .channel('call:$callId')
      .onBroadcast(
        event: 'signal',
        callback: (message) {
          final data = (message['payload'] as Map?)?.cast<String, dynamic>() ?? message;
          if (data['from'] != myId) onSignal(data);
        },
      )
      .subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) onJoined();
      });

  Future<void> sendSignal(RealtimeChannel channel, Map<String, dynamic> signal) =>
      channel.sendBroadcastMessage(event: 'signal', payload: {...signal, 'from': myId});

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
