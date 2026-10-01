import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/utils/error_message.dart';
import '../../blocking/blocked_users_controller.dart';
import '../../calls/application/call_session_controller.dart';
import '../../notifications/push_controller.dart';
import '../../presence/presence_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import '../application/chat_list_controller.dart';
import '../application/chat_live_controllers.dart';
import '../application/chat_messages_controller.dart';
import '../domain/message.dart';
import '../domain/chat.dart';
import '../domain/receipt.dart';
import '../domain/system_event.dart';
import 'group_event_text.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  late final ActiveChatController _activeChat;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Suppresses notifications for this chat while it's on screen.
    _activeChat = ref.read(activeChatProvider.notifier);
    Future.microtask(() => _activeChat.enter(widget.chatId));
  }

  @override
  void dispose() {
    // Deferred: providers can't be modified while the widget tree is being torn down.
    Future.microtask(() => _activeChat.leave(widget.chatId));
    _scrollController.dispose();
    super.dispose();
  }

  /// The list is reversed, so the max extent is the oldest message.
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      ref.read(chatMessagesProvider(widget.chatId).notifier).loadMore();
    }
  }

  /// The list is reversed, so offset 0 is the newest message.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _send(String text) {
    ref.read(chatTypingProvider(widget.chatId).notifier).stopped();
    ref.read(chatMessagesProvider(widget.chatId).notifier).sendText(text);
    _scrollToBottom();
  }

  void _sendImages(List<String> paths) {
    ref.read(chatMessagesProvider(widget.chatId).notifier).sendImages(paths);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = ref.watch(supabaseProvider).auth.currentUser!.id;
    final chat = ref.watch(chatDetailsProvider(widget.chatId)).value;
    final state = ref.watch(chatMessagesProvider(widget.chatId));
    final l10n = context.l10n;
    final title = chat?.title(myId) ?? '';
    final isGroup = chat?.isGroup ?? false;
    final peer = chat?.peer(myId);
    final typingIds = ref.watch(chatTypingProvider(widget.chatId));
    final online = peer != null && ref.watch(presenceProvider).contains(peer.id);
    // Live copy of the peer's profile so "last seen" updates while the screen is open.
    final lastSeen = peer == null ? null : (ref.watch(profileStreamProvider(peer.id)).value ?? peer).lastSeenAt;
    // Removed from (or left) a group: keep the history readable but disable sending.
    final canSend = chat == null || !isGroup || chat.member(myId) != null;
    final blockedPeer = peer != null && (ref.watch(blockedUsersProvider).value?.any((p) => p.id == peer.id) ?? false);

    String? status;
    var statusColor = theme.colorScheme.primary;
    if (typingIds.isNotEmpty) {
      status = isGroup ? '${_nameOf(chat, typingIds.first)} ${l10n.typing}' : l10n.typing;
    } else if (isGroup) {
      status = [for (final m in chat!.members) m.userId == myId ? l10n.you : m.profile.displayName].join('، ');
      statusColor = theme.colorScheme.onSurfaceVariant;
    } else if (online) {
      status = l10n.online;
    } else if (lastSeen != null) {
      status = lastSeenLabel(context, lastSeen);
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: isGroup ? () => context.push(Routes.groupInfo(widget.chatId)) : null,
          child: Row(
            children: [
              UserAvatar(url: chat?.avatar(myId), name: title, radius: 20, online: online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (status != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          status,
                          key: ValueKey(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (peer != null) ...[
            IconButton(
              tooltip: l10n.videoCall,
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => ref.read(callSessionProvider.notifier).startOutgoing(peer, video: true),
            ),
            IconButton(
              tooltip: l10n.audioCall,
              icon: const Icon(Icons.call_outlined),
              onPressed: () => ref.read(callSessionProvider.notifier).startOutgoing(peer, video: false),
            ),
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => blockedPeer ? _unblock(peer.id) : _confirmBlock(peer),
                  child: Text(blockedPeer ? l10n.unblockUser : l10n.blockUser),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(context, state, myId, chat)),
          if (blockedPeer)
            _ComposerBanner(text: l10n.youBlockedThem, actionLabel: l10n.unblockUser, onAction: () => _unblock(peer.id))
          else if (!canSend)
            _ComposerBanner(text: l10n.notAMember)
          else
            MessageComposer(
              onSend: _send,
              onPickImages: _sendImages,
              onVoiceRecorded: (recording) {
                ref.read(chatMessagesProvider(widget.chatId).notifier).sendVoice(recording);
                _scrollToBottom();
              },
              onTyping: ref.read(chatTypingProvider(widget.chatId).notifier).typing,
              onStopTyping: ref.read(chatTypingProvider(widget.chatId).notifier).stopped,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmBlock(Profile peer) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.blockConfirm(peer.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.blockUser),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(blockedUsersProvider.notifier).block(peer);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  Future<void> _unblock(String userId) async {
    try {
      await ref.read(blockedUsersProvider.notifier).unblock(userId);
    } catch (e) {
      if (mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  /// Display name for a user id: current member, else a fetched profile (former members).
  String _nameOf(Chat? chat, String userId) =>
      chat?.member(userId)?.profile.displayName ??
      ref.watch(profileByIdProvider(userId)).value?.displayName ??
      context.l10n.someone;

  Widget _buildMessages(BuildContext context, ChatMessagesState state, String myId, Chat? chat) {
    final receipts = ref.watch(chatReceiptsProvider(widget.chatId));
    final others = [
      for (final r in receipts.values)
        if (r.userId != myId) r,
    ];
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (state.loading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadFailed),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: ref.read(chatMessagesProvider(widget.chatId).notifier).retryLoad,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (state.messages.isEmpty) {
      return Center(
        child: Text(l10n.sayHi, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    final messages = state.messages;
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length + (state.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final message = messages[i];
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final newer = i > 0 ? messages[i - 1] : null;
        final startsDay = older == null || !isSameDay(older.createdAt, message.createdAt);
        // Tighter spacing between consecutive messages from the same sender.
        final groupedWithNewer =
            newer != null &&
            newer.type != MessageType.system &&
            newer.senderId == message.senderId &&
            isSameDay(newer.createdAt, message.createdAt);
        // First bubble of a run from someone else in a group gets their name on top.
        final startsRun =
            older == null || startsDay || older.type == MessageType.system || older.senderId != message.senderId;
        final mine = message.senderId == myId;

        final event = GroupEvent.fromMessage(message);
        if (event != null) {
          return Column(
            children: [
              if (startsDay) _DaySeparator(label: dayLabel(context, message.createdAt)),
              _DaySeparator(
                label: describeGroupEvent(l10n, event, myId: myId, nameOf: (id) => _nameOf(chat, id)),
              ),
            ],
          );
        }

        final showSender = (chat?.isGroup ?? false) && !mine && startsRun && message.senderId != null;
        return Column(
          children: [
            if (startsDay) _DaySeparator(label: dayLabel(context, message.createdAt)),
            MessageBubble(
              message: message,
              mine: mine,
              tail: !groupedWithNewer,
              senderName: showSender ? _nameOf(chat, message.senderId!) : null,
              receipt: receiptStatus(message.createdAt, others),
              onRetry: message.sendStatus == SendStatus.failed
                  ? () => ref.read(chatMessagesProvider(widget.chatId).notifier).retry(message)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
        ),
      ),
    );
  }
}

/// Replaces the composer when sending isn't possible, with an optional fix.
class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: theme.colorScheme.surfaceContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
