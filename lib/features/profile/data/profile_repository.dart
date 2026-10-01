import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/core_providers.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(supabaseProvider)));

/// One-off profile lookup, e.g. for a former group member named in a system message.
final profileByIdProvider = FutureProvider.family<Profile?, String>(
  (ref, userId) => ref.watch(profileRepositoryProvider).fetch(userId),
);

final profileStreamProvider = StreamProvider.autoDispose.family<Profile, String>(
  (ref, userId) => ref.watch(profileRepositoryProvider).watch(userId),
);

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  Future<Profile?> fetch(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Live profile, used for a chat partner's up-to-date "last seen".
  Stream<Profile> watch(String userId) => _client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => Profile.fromJson(rows.first));

  Future<bool> isUsernameAvailable(String username) async {
    final result = await _client.rpc<bool>('is_username_available', params: {'p_username': username.toLowerCase()});
    return result;
  }

  /// Compresses the image and uploads it to `avatars/<uid>/`, returning its public URL.
  Future<String> uploadAvatar(File image) async {
    final uid = _client.auth.currentUser!.id;
    final bytes = await FlutterImageCompress.compressWithFile(
      image.absolute.path,
      minWidth: 512,
      minHeight: 512,
      quality: 82,
    );
    if (bytes == null) throw const FormatException('Could not read image');

    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  Future<Profile> create({
    required String username,
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser!;
    final row = await _client
        .from('profiles')
        .insert({
          'id': user.id,
          // Overwritten server-side from auth.users; sent only to satisfy NOT NULL.
          'phone': user.phone ?? '',
          'username': username.toLowerCase(),
          'display_name': displayName.trim(),
          'bio': (bio?.trim().isEmpty ?? true) ? null : bio!.trim(),
          'avatar_url': avatarUrl,
        })
        .select()
        .single();
    return Profile.fromJson(row);
  }
}
