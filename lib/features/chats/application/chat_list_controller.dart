import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';

final chatListProvider = AsyncNotifierProvider<ChatListController, List<Chat>>(ChatListController.new);

/// A single chat's details (header, members), refreshed when the list changes.
final chatDetailsProvider = FutureProvider.autoDispose.family<Chat, String>((ref, chatId) {
  final cached = ref.watch(chatListProvider).value?.where((c) => c.id == chatId).firstOrNull;
  if (cached != null) return cached;
  return ref.watch(chatRepositoryProvider).fetchChat(chatId);
});

/// Badge count for the Chats tab.
final totalUnreadProvider = Provider<int>((ref) {
  final chats = ref.watch(chatListProvider).value ?? const [];
  return chats.fold(0, (sum, c) => sum + c.unreadCount);
});

class ChatListController extends AsyncNotifier<List<Chat>> {
  Timer? _debounce;

  @override
  Future<List<Chat>> build() async {
    // Rebuild from scratch when a different user signs in.
    ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
    final repo = ref.watch(chatRepositoryProvider);

    final channel = repo.subscribeToChatList(_scheduleRefresh);
    final lifecycle = AppLifecycleListener(onShow: _scheduleRefresh);
    ref.onDispose(() {
      _debounce?.cancel();
      lifecycle.dispose();
      repo.unsubscribe(channel);
    });

    // Offline-first: show the saved list instantly, then revalidate in the background.
    final cached = await repo.cachedChats();
    if (cached != null) {
      Future.microtask(refresh);
      return cached;
    }

    final chats = await repo.fetchChats();
    _markDelivered(chats);
    return chats;
  }

  /// Bursts of realtime events (message + member updates) collapse into one fetch.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(ref.read(chatRepositoryProvider).fetchChats);
    if (!ref.mounted) return;
    // Keep showing the last good list if a background refresh fails.
    if (result.hasValue || !state.hasValue) state = result;
    if (result.value case final chats?) _markDelivered(chats);
  }

  /// Seeing a chat in the list means its messages reached this device.
  /// The RPC only touches chats that actually have undelivered messages.
  void _markDelivered(List<Chat> chats) {
    if (!chats.any((c) => c.unreadCount > 0)) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    ref.read(chatRepositoryProvider).markAllDelivered().ignore();
  }
}
