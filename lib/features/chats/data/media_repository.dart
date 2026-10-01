import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageDescriptor, ImmutableBuffer;

import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/core_providers.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) => MediaRepository(ref.watch(supabaseProvider)));

/// Short-lived signed URL for a private chat file, cached a little under its lifetime.
final mediaUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, path) async {
  final url = await ref.watch(mediaRepositoryProvider).signedUrl(path);
  final link = ref.keepAlive();
  final timer = Timer(MediaRepository.signedUrlLifetime - const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return url;
});

class CompressedImage {
  const CompressedImage(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

class MediaRepository {
  MediaRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'chat-media';
  static const signedUrlLifetime = Duration(hours: 1);
  static const _maxImageSide = 1600;
  static const _chunkSize = 64 * 1024;

  /// Re-encodes to JPEG with the longest side capped at [_maxImageSide].
  /// Also normalises HEIC/PNG and strips EXIF (location) data.
  Future<CompressedImage> compressImage(String filePath) async {
    final original = await _dimensions(filePath);
    final scale = math.min(1.0, _maxImageSide / math.max(original.width, original.height));
    final bytes = await FlutterImageCompress.compressWithFile(
      filePath,
      minWidth: (original.width * scale).round(),
      minHeight: (original.height * scale).round(),
      quality: 80,
      keepExif: false,
    );
    if (bytes == null) throw const FormatException('Unsupported image');
    final size = await _decodeSize(bytes);
    return CompressedImage(bytes, size.width.round(), size.height.round());
  }

  /// Uploads straight to the Storage REST endpoint as a stream, so we can
  /// report real progress (the SDK's upload has no progress callback).
  Future<String> uploadChatImage({
    required String chatId,
    required String clientId,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) => _upload(
    chatId: chatId,
    fileName: '$clientId.jpg',
    contentType: 'image/jpeg',
    bytes: bytes,
    onProgress: onProgress,
  );

  Future<String> uploadVoice({
    required String chatId,
    required String clientId,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) => _upload(
    chatId: chatId,
    fileName: '$clientId.m4a',
    contentType: 'audio/mp4',
    bytes: bytes,
    onProgress: onProgress,
  );

  Future<String> _upload({
    required String chatId,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final session = _client.auth.currentSession!;
    // Folder layout matches the storage RLS policy: <chat_id>/<user_id>/<file>.
    final path = '$chatId/${session.user.id}/$fileName';

    final request = http.StreamedRequest('POST', Uri.parse('${Env.supabaseUrl}/storage/v1/object/$bucket/$path'))
      ..headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': Env.supabasePublishableKey,
        'Content-Type': contentType,
        'x-upsert': 'false',
        'cache-control': 'max-age=31536000',
      })
      ..contentLength = bytes.length;

    final httpClient = http.Client();
    final http.Response response;
    try {
      final responseFuture = httpClient.send(request);
      for (var offset = 0; offset < bytes.length; offset += _chunkSize) {
        final end = math.min(offset + _chunkSize, bytes.length);
        request.sink.add(bytes.sublist(offset, end));
        onProgress?.call(end / bytes.length);
        // Yield between chunks so progress roughly tracks what the socket has taken.
        await Future<void>.delayed(Duration.zero);
      }
      unawaited(request.sink.close());
      response = await http.Response.fromStream(await responseFuture);
    } finally {
      httpClient.close();
    }
    // 409 = already uploaded by an earlier attempt of this same message.
    if (response.statusCode == 409 || (response.statusCode >= 200 && response.statusCode < 300)) {
      return path;
    }
    throw StorageException(response.body, statusCode: '${response.statusCode}');
  }

  Future<String> signedUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, signedUrlLifetime.inSeconds);

  Future<Size> _dimensions(String filePath) async {
    final codec = await ImageDescriptor.encoded(await ImmutableBuffer.fromFilePath(filePath));
    final size = Size(codec.width.toDouble(), codec.height.toDouble());
    codec.dispose();
    return size;
  }

  Future<Size> _decodeSize(Uint8List bytes) async {
    final descriptor = await ImageDescriptor.encoded(await ImmutableBuffer.fromUint8List(bytes));
    final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    descriptor.dispose();
    return size;
  }
}
