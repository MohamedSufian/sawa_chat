import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_repository.dart';
import '../domain/receipt.dart';

// ---- Read / delivered watermarks of every member in an open chat ------------

final chatReceiptsProvider = NotifierProvider.autoDispose
    .family<ChatReceiptsController, Map<String, MemberReceipt>, String>(ChatReceiptsController.new);

class ChatReceiptsController extends Notifier<Map<String, MemberReceipt>> {
  ChatReceiptsController(this.chatId);

  final String chatId;

  @override
  Map<String, MemberReceipt> build() {
    final repo = ref.watch(chatRepositoryProvider);
    final channel = repo.subscribeToReceipts(chatId, _merge);
    ref.onDispose(() => repo.unsubscribe(channel));

    Future.microtask(() async {
      try {
        final receipts = await repo.fetchReceipts(chatId);
        if (ref.mounted) receipts.forEach(_merge);
      } catch (_) {
        // Ticks simply stay at "sent" until a realtime update arrives.
      }
    });
    return const {};
  }

  /// Watermarks only move forward, so keep whichever copy is newer.
  void _merge(MemberReceipt receipt) {
    final current = state[receipt.userId];
    if (current != null &&
        !receipt.lastReadAt.isAfter(current.lastReadAt) &&
        !receipt.lastDeliveredAt.isAfter(current.lastDeliveredAt)) {
      return;
    }
    state = {...state, receipt.userId: receipt};
  }
}

// ---- "typing…" ----------------------------------------------------------------

final chatTypingProvider = NotifierProvider.autoDispose.family<ChatTypingController, Set<String>, String>(
  ChatTypingController.new,
);

/// Users currently typing in a chat, over Realtime Broadcast.
class ChatTypingController extends Notifier<Set<String>> {
  ChatTypingController(this.chatId);

  final String chatId;

  /// Senders re-announce while typing; receivers forget after this long without news.
  static const _resendEvery = Duration(milliseconds: 2500);
  static const _expireAfter = Duration(seconds: 5);

  late RealtimeChannel _channel;
  final _expiry = <String, Timer>{};
  DateTime? _lastSent;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Set<String> build() {
    final repo = ref.watch(chatRepositoryProvider);
    _channel = repo.typingChannel(chatId, _onEvent);
    ref.onDispose(() {
      for (final t in _expiry.values) {
        t.cancel();
      }
      if (_lastSent != null) repo.sendTyping(_channel, typing: false).ignore();
      repo.unsubscribe(_channel);
    });
    return const {};
  }

  void _onEvent(String userId, bool typing) {
    _expiry.remove(userId)?.cancel();
    if (typing) {
      _expiry[userId] = Timer(_expireAfter, () => _remove(userId));
      if (!state.contains(userId)) state = {...state, userId};
    } else {
      _remove(userId);
    }
  }

  void _remove(String userId) {
    _expiry.remove(userId)?.cancel();
    if (ref.mounted && state.contains(userId)) state = {...state}..remove(userId);
  }

  /// Call on every keystroke; throttled to one broadcast per [_resendEvery].
  void typing() {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < _resendEvery) return;
    _lastSent = now;
    _repo.sendTyping(_channel, typing: true).ignore();
  }

  /// Call when the text is sent or cleared.
  void stopped() {
    if (_lastSent == null) return;
    _lastSent = null;
    _repo.sendTyping(_channel, typing: false).ignore();
  }
}
