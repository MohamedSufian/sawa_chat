import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/core_providers.dart';
import '../data/chat_repository.dart';
import '../data/media_repository.dart';
import '../domain/message.dart';
import '../domain/voice.dart';

class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  /// Newest first, matching the reversed list view.
  final List<Message> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  ChatMessagesState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
  }) => ChatMessagesState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
  );
}

final chatMessagesProvider = NotifierProvider.autoDispose.family<ChatMessagesController, ChatMessagesState, String>(
  ChatMessagesController.new,
);

class ChatMessagesController extends Notifier<ChatMessagesState> {
  ChatMessagesController(this.chatId);

  final String chatId;

  static const _pageSize = 40;
  static const _uuid = Uuid();

  Timer? _markReadDebounce;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  MediaRepository get _media => ref.read(mediaRepositoryProvider);
  String get _myId => ref.read(supabaseProvider).auth.currentUser!.id;

  @override
  ChatMessagesState build() {
    final repo = ref.watch(chatRepositoryProvider);
    final channel = repo.subscribeToMessages(chatId, _onRemoteMessage);
    // Realtime can miss events while the app is in the background.
    final lifecycle = AppLifecycleListener(onShow: _catchUp);
    ref.onDispose(() {
      lifecycle.dispose();
      _markReadDebounce?.cancel();
      repo.unsubscribe(channel);
    });

    Future.microtask(_loadInitial);
    return const ChatMessagesState();
  }

  Future<void> _loadInitial() async {
    // Offline-first: the saved newest page shows instantly and stays readable without internet.
    final cached = await _repo.cachedMessages(chatId);
    if (!ref.mounted) return;
    if (cached != null && cached.isNotEmpty) {
      cached.forEach(_upsert);
      state = state.copyWith(loading: false);
    }

    try {
      final page = await _repo.fetchMessages(chatId, limit: _pageSize);
      if (!ref.mounted) return;
      // Merge: realtime may already have delivered something while we fetched.
      state = state.copyWith(loading: false, hasMore: page.length == _pageSize);
      page.forEach(_upsert);
      _scheduleMarkRead();
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> _catchUp() async {
    try {
      final latest = await _repo.fetchMessages(chatId, limit: _pageSize);
      if (!ref.mounted) return;
      latest.forEach(_upsert);
      _scheduleMarkRead();
    } catch (_) {}
  }

  Future<void> retryLoad() async {
    state = state.copyWith(loading: true);
    await _loadInitial();
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    try {
      final oldest = state.messages.lastWhere((m) => m.id != null, orElse: () => state.messages.last);
      final page = await _repo.fetchMessages(chatId, before: oldest.createdAt, limit: _pageSize);
      if (!ref.mounted) return;
      page.forEach(_upsert);
      state = state.copyWith(loadingMore: false, hasMore: page.length == _pageSize);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;

    final pending = Message(
      clientId: _uuid.v4(),
      chatId: chatId,
      senderId: _myId,
      type: MessageType.text,
      content: content,
      createdAt: DateTime.now(),
      sendStatus: SendStatus.sending,
    );
    _upsert(pending);
    await _deliver(pending);
  }

  /// Compresses each picked image, shows it immediately, and uploads them in parallel.
  Future<void> sendImages(List<String> filePaths) async {
    for (final filePath in filePaths) {
      final CompressedImage image;
      try {
        image = await _media.compressImage(filePath);
      } catch (_) {
        continue; // Unreadable file; skip it rather than block the others.
      }
      if (!ref.mounted) return;

      final pending = Message(
        clientId: _uuid.v4(),
        chatId: chatId,
        senderId: _myId,
        type: MessageType.image,
        mediaMeta: {'width': image.width, 'height': image.height},
        createdAt: DateTime.now(),
        sendStatus: SendStatus.sending,
        localBytes: image.bytes,
        uploadProgress: 0,
      );
      _upsert(pending);
      unawaited(_deliver(pending));
    }
  }

  Future<void> sendVoice(VoiceRecording recording) async {
    final pending = Message(
      clientId: _uuid.v4(),
      chatId: chatId,
      senderId: _myId,
      type: MessageType.voice,
      mediaMeta: {'duration_ms': recording.duration.inMilliseconds, 'waveform': recording.waveform},
      createdAt: DateTime.now(),
      sendStatus: SendStatus.sending,
      localPath: recording.path,
      uploadProgress: 0,
    );
    _upsert(pending);
    await _deliver(pending);
  }

  Future<void> retry(Message message) async {
    final pending = message.copyWith(
      sendStatus: SendStatus.sending,
      uploadProgress: message.mediaPath == null && _hasLocalMedia(message) ? 0 : null,
    );
    _upsert(pending);
    await _deliver(pending);
  }

  /// Upload (if the message has media not yet stored) then insert the row.
  /// On failure the message keeps whatever already succeeded, so a retry
  /// never re-uploads a file that is already in storage.
  Future<void> _deliver(Message pending) async {
    var message = pending;
    try {
      if (message.mediaPath == null && _hasLocalMedia(message)) {
        var reported = 0.0;
        void onProgress(double p) {
          // Throttle UI updates to every 5%.
          if (p < 1 && p - reported < 0.05) return;
          reported = p;
          if (ref.mounted) _upsert(message.copyWith(uploadProgress: p));
        }

        final path = message.type == MessageType.voice
            ? await _media.uploadVoice(
                chatId: chatId,
                clientId: message.clientId,
                bytes: await File(message.localPath!).readAsBytes(),
                onProgress: onProgress,
              )
            : await _media.uploadChatImage(
                chatId: chatId,
                clientId: message.clientId,
                bytes: message.localBytes!,
                onProgress: onProgress,
              );
        message = message.copyWith(mediaPath: path, uploadProgress: 1);
      }
      final saved = await _repo.send(message);
      if (ref.mounted) _upsert(saved);
    } catch (_) {
      if (ref.mounted) _upsert(message.copyWith(sendStatus: SendStatus.failed, clearProgress: true));
    }
  }

  void _onRemoteMessage(Message message) {
    _upsert(message);
    if (message.senderId != _myId) _scheduleMarkRead();
  }

  void _scheduleMarkRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 500), () {
      // Only count messages as read while the user can actually see them.
      if (ref.mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _repo.markRead(chatId).ignore();
      }
    });
  }

  /// Inserts or replaces by `clientId`, so the optimistic bubble, the insert
  /// response and the realtime echo all collapse into one message.
  void _upsert(Message message) {
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.clientId == message.clientId);
    if (index >= 0) {
      final existing = messages[index];
      // Never downgrade a stored message back to "sending"/"failed".
      if (existing.id != null && message.id == null) return;
      // Keep local media so the bubble doesn't flicker to a network load.
      messages[index] = message.copyWith(
        localBytes: message.localBytes ?? existing.localBytes,
        localPath: message.localPath ?? existing.localPath,
      );
    } else {
      messages.add(message);
    }
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(messages: messages);
  }

  static bool _hasLocalMedia(Message m) => m.localBytes != null || m.localPath != null;
}
