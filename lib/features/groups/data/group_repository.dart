import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository(ref.watch(supabaseProvider)));

/// Group management. Every call goes through a `security definer` RPC that
/// checks the caller's role and logs a system message (migration 0003).
class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient _client;

  Future<String> create({required String name, required List<String> memberIds, File? avatar}) async {
    final chatId = await _client.rpc<String>('create_group', params: {'p_name': name, 'p_member_ids': memberIds});
    if (avatar != null) {
      // The chat id is only known now, and the storage policy keys group photos on it.
      final url = await uploadAvatar(chatId, avatar);
      await update(chatId, avatarUrl: url);
    }
    return chatId;
  }

  Future<void> update(String chatId, {String? name, String? description, String? avatarUrl}) => _client.rpc<void>(
    'update_group',
    params: {'p_chat_id': chatId, 'p_name': name, 'p_description': description, 'p_avatar_url': avatarUrl},
  );

  Future<void> addMembers(String chatId, List<String> userIds) =>
      _client.rpc<void>('add_group_members', params: {'p_chat_id': chatId, 'p_member_ids': userIds});

  Future<void> removeMember(String chatId, String userId) =>
      _client.rpc<void>('remove_group_member', params: {'p_chat_id': chatId, 'p_user_id': userId});

  Future<void> leave(String chatId) => removeMember(chatId, _client.auth.currentUser!.id);

  Future<void> setRole(String chatId, String userId, {required bool admin}) => _client.rpc<void>(
    'set_member_role',
    params: {'p_chat_id': chatId, 'p_user_id': userId, 'p_role': admin ? 'admin' : 'member'},
  );

  /// Uploads to `avatars/groups/<chat_id>/` and returns the public URL.
  Future<String> uploadAvatar(String chatId, File image) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      image.absolute.path,
      minWidth: 512,
      minHeight: 512,
      quality: 82,
      keepExif: false,
    );
    if (bytes == null) throw const FormatException('Could not read image');

    final path = 'groups/$chatId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}
