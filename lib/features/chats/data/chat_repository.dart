import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/json_cache.dart';
import '../../../core/providers/core_providers.dart';
import '../../profile/domain/profile.dart';
import '../domain/chat.dart';
import '../domain/message.dart';
import '../domain/receipt.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseProvider), ref.watch(jsonCacheProvider)),
);

class ChatRepository {
  ChatRepository(this._client, this._cache);

  final SupabaseClient _client;
  final JsonCache _cache;

  static const _chatSelect =
      '*, unread_count, '
      'last_message:messages!chats_last_message_fk(*), '
      'members:chat_members(user_id, role, last_read_at, last_delivered_at, muted, profile:profiles(*))';

  String get _myId => _client.auth.currentUser!.id;

  // ---- Users & chats -------------------------------------------------------

  Future<List<Profile>> searchUsers(String query) async {
    final rows = await _client.rpc<List<dynamic>>('search_users', params: {'p_query': query});
    return rows.map((r) => Profile.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Returns the id of the direct chat with [userId], creating it if needed.
  Future<String> openDirectChat(String userId) =>
      _client.rpc<String>('get_or_create_direct_chat', params: {'p_other_user': userId});

  /// Chats to show in the list: groups, and direct chats that have messages.
  /// Every successful fetch also refreshes the offline copy.
  Future<List<Chat>> fetchChats() async {
    final rows = await _client
        .from('chats')
        .select(_chatSelect)
        .or('last_message_at.not.is.null,type.eq.group')
        .order('last_message_at', ascending: false, nullsFirst: false);
    await _cache.writeRows('chats_$_myId', rows);
    return rows.map(Chat.fromJson).toList();
  }

  /// Last chat list seen on this device, or null.
  Future<List<Chat>?> cachedChats() async => (await _cache.readRows('chats_$_myId'))?.map(Chat.fromJson).toList();

  Future<Chat> fetchChat(String chatId) async =>
      Chat.fromJson(await _client.from('chats').select(_chatSelect).eq('id', chatId).single());

  // ---- Messages ------------------------------------------------------------

  /// Newest first. Pass [before] to page back in history.
  Future<List<Message>> fetchMessages(String chatId, {DateTime? before, int limit = 40}) async {
    var query = _client.from('messages').select().eq('chat_id', chatId);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(limit);
    // Keep the newest page for offline reading.
    if (before == null) await _cache.writeRows('messages_$chatId', rows);
    return rows.map(Message.fromJson).toList();
  }

  /// Newest page of a chat as last seen on this device, or null.
  Future<List<Message>?> cachedMessages(String chatId) async =>
      (await _cache.readRows('messages_$chatId'))?.map(Message.fromJson).toList();

  /// Stores a text or (already uploaded) media message.
  Future<Message> send(Message pending) async {
    try {
      final row = await _client
          .from('messages')
          .insert({
            'client_id': pending.clientId,
            'chat_id': pending.chatId,
            'sender_id': _myId,
            'type': pending.type.name,
            'content': pending.content,
            'media_path': pending.mediaPath,
            'media_meta': pending.mediaMeta,
          })
          .select()
          .single();
      return Message.fromJson(row);
    } on PostgrestException catch (e) {
      // A retry after a lost response: the row already exists.
      if (e.code != '23505') rethrow;
      final row = await _client.from('messages').select().eq('client_id', pending.clientId).single();
      return Message.fromJson(row);
    }
  }

  Future<void> markRead(String chatId) => _client.rpc<void>('mark_chat_read', params: {'p_chat_id': chatId});

  /// Marks every chat with unseen messages as delivered to this device.
  Future<void> markAllDelivered() => _client.rpc<void>('mark_all_delivered');

  // ---- Receipts ------------------------------------------------------------

  Future<List<MemberReceipt>> fetchReceipts(String chatId) async {
    final rows = await _client
        .from('chat_members')
        .select('user_id, last_delivered_at, last_read_at')
        .eq('chat_id', chatId);
    return rows.map(MemberReceipt.fromJson).toList();
  }

  RealtimeChannel subscribeToReceipts(String chatId, void Function(MemberReceipt) onChange) {
    return _client
        .channel('receipts:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_members',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId),
          callback: (p) => onChange(MemberReceipt.fromJson(p.newRecord)),
        )
        .subscribe();
  }

  // ---- Typing --------------------------------------------------------------

  /// Ephemeral broadcast channel; nothing is written to the database.
  RealtimeChannel typingChannel(String chatId, void Function(String userId, bool typing) onEvent) {
    return _client
        .channel('typing:$chatId')
        .onBroadcast(
          event: 'typing',
          callback: (message) {
            final data = (message['payload'] as Map?)?.cast<String, dynamic>() ?? message;
            final userId = data['user_id'] as String?;
            if (userId != null && userId != _myId) onEvent(userId, data['typing'] as bool? ?? true);
          },
        )
        .subscribe();
  }

  Future<void> sendTyping(RealtimeChannel channel, {required bool typing}) =>
      channel.sendBroadcastMessage(event: 'typing', payload: {'user_id': _myId, 'typing': typing});

  // ---- Realtime ------------------------------------------------------------

  RealtimeChannel subscribeToMessages(String chatId, void Function(Message) onUpsert) {
    void handle(PostgresChangePayload p) => onUpsert(Message.fromJson(p.newRecord));
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: chatId);

    return _client
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: filter,
          callback: handle,
        )
        .subscribe();
  }

  /// Fires whenever any of my chats changes or I'm added to a new one.
  RealtimeChannel subscribeToChatList(void Function() onChange) {
    return _client
        .channel('chat-list:$_myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_members',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: _myId),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
