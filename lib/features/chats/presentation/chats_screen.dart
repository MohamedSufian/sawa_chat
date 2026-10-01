import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../application/chat_list_controller.dart';
import '../../presence/presence_controller.dart';
import '../domain/chat.dart';
import '../domain/message.dart';
import '../domain/receipt.dart';
import '../domain/system_event.dart';
import 'group_event_text.dart';
import 'message_preview.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chats = ref.watch(chatListProvider);
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id)) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.newGroup,
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => context.push(Routes.newGroup),
          ),
          IconButton(
            tooltip: l10n.newChat,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: switch (chats) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.forum_outlined,
          title: l10n.noChatsTitle,
          body: l10n.noChatsBody,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: ref.read(chatListProvider.notifier).refresh,
          child: ListView.builder(
            itemCount: value.length,
            itemBuilder: (context, i) => _ChatTile(chat: value[i], myId: myId),
          ),
        ),
        AsyncError() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorGeneric),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => ref.invalidate(chatListProvider), child: Text(l10n.retry)),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newChat,
        onPressed: () => context.push(Routes.search),
        child: const Icon(Icons.edit_square),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat, required this.myId});

  final Chat chat;
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = chat.title(myId);
    final last = chat.lastMessage;
    final mine = last?.senderId == myId && last?.type != MessageType.system && last?.type != MessageType.call;
    final unread = chat.unreadCount;
    final peerId = chat.peer(myId)?.id;
    final online = peerId != null && ref.watch(presenceProvider.select((ids) => ids.contains(peerId)));

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6),
      leading: UserAvatar(url: chat.avatar(myId), name: title, radius: 28, online: online),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: last == null
          ? null
          : Row(
              children: [
                if (mine) ...[_ReceiptTicks(status: chat.receiptFor(last, myId)), const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    _preview(context, last, mine),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: unread > 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            chatListTime(context, chat.sortTime),
            style: theme.textTheme.labelSmall?.copyWith(
              color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: unread > 0 ? FontWeight.w700 : null,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 6),
            Semantics(
              label: context.l10n.unreadCount(unread),
              child: Badge.count(
                count: unread,
                maxCount: 99,
                backgroundColor: scheme.primary,
                textColor: scheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push(Routes.chat(chat.id)),
    );
  }

  String _preview(BuildContext context, Message last, bool mine) {
    final l10n = context.l10n;
    String nameOf(String id) => chat.member(id)?.profile.displayName ?? l10n.someone;
    final event = GroupEvent.fromMessage(last);
    return messagePreview(
      l10n,
      last,
      mine: mine,
      // In groups, say who wrote it.
      senderName: chat.isGroup && last.senderId != null ? nameOf(last.senderId!) : null,
      systemText: event == null ? null : describeGroupEvent(l10n, event, myId: myId, nameOf: nameOf),
    );
  }
}

class _ReceiptTicks extends StatelessWidget {
  const _ReceiptTicks({required this.status});

  final ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return switch (status) {
      ReceiptStatus.sent => Icon(Icons.check_rounded, size: 16, color: muted),
      ReceiptStatus.delivered => Icon(Icons.done_all_rounded, size: 16, color: muted),
      ReceiptStatus.read => const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF34B7F1)),
    };
  }
}
