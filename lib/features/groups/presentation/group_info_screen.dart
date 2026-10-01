import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../../chats/application/chat_list_controller.dart';
import '../../chats/data/chat_repository.dart';
import '../../chats/domain/chat.dart';
import '../../presence/presence_controller.dart';
import '../../profile/domain/profile.dart';
import '../data/group_repository.dart';
import 'select_members_screen.dart';

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id)) ?? '';
    final chat = ref.watch(chatDetailsProvider(chatId)).value;

    if (chat == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return _GroupInfoBody(chat: chat, myId: myId);
  }
}

class _GroupInfoBody extends ConsumerWidget {
  const _GroupInfoBody({required this.chat, required this.myId});

  final Chat chat;
  final String myId;

  GroupRepository _repo(WidgetRef ref) => ref.read(groupRepositoryProvider);

  /// Runs a group action, reports failures, and refreshes the cached chat.
  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null || !context.mounted) return;
    await _run(context, ref, () async {
      final url = await _repo(ref).uploadAvatar(chat.id, File(picked.path));
      await _repo(ref).update(chat.id, avatarUrl: url);
    });
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = TextEditingController(text: chat.name);
    final description = TextEditingController(text: chat.description);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editGroup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 50,
              decoration: InputDecoration(labelText: l10n.groupName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: l10n.groupDescription),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => _repo(ref).update(chat.id, name: name.text.trim(), description: description.text.trim()),
    );
  }

  Future<void> _addMembers(BuildContext context, WidgetRef ref) async {
    final selected = await Navigator.of(context).push<List<Profile>>(
      MaterialPageRoute(
        builder: (_) => SelectMembersScreen(
          title: context.l10n.addMembers,
          excludeIds: {for (final m in chat.members) m.userId},
          doneIcon: Icons.check_rounded,
          onDone: (ctx, people) => Navigator.pop(ctx, people),
        ),
      ),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    await _run(context, ref, () => _repo(ref).addMembers(chat.id, [for (final p in selected) p.id]));
  }

  Future<void> _memberActions(BuildContext context, WidgetRef ref, ChatMember member) async {
    final l10n = context.l10n;
    final iAmAdmin = chat.isAdmin(myId);
    final canManage = iAmAdmin && member.role != 'owner';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: UserAvatar(url: member.profile.avatarUrl, name: member.profile.displayName),
              title: Text(member.profile.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(ltrIsolate('@${member.profile.username}')),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: Text(l10n.sendMessage),
              onTap: () async {
                Navigator.pop(sheetContext);
                final id = await ref.read(chatRepositoryProvider).openDirectChat(member.userId);
                if (context.mounted) context.push(Routes.chat(id));
              },
            ),
            if (canManage)
              ListTile(
                leading: Icon(member.role == 'admin' ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined),
                title: Text(member.role == 'admin' ? l10n.dismissAdmin : l10n.makeAdmin),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _run(context, ref, () => _repo(ref).setRole(chat.id, member.userId, admin: member.role != 'admin'));
                },
              ),
            if (canManage)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
                title: Text(l10n.removeFromGroup, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _run(context, ref, () => _repo(ref).removeMember(chat.id, member.userId));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.leaveGroupConfirm(chat.name ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leaveGroup),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await _repo(ref).leave(chat.id);
      if (context.mounted) context.go(Routes.chats);
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iAmAdmin = chat.isAdmin(myId);
    final online = ref.watch(presenceProvider);

    // Owner first, then admins, then everyone else by name; me at the top of my group.
    int rank(ChatMember m) => switch (m.role) {
      'owner' => 0,
      'admin' => 1,
      _ => 2,
    };
    final members = [...chat.members]
      ..sort((a, b) {
        if (a.userId == myId) return -1;
        if (b.userId == myId) return 1;
        final byRole = rank(a).compareTo(rank(b));
        return byRole != 0 ? byRole : a.profile.displayName.compareTo(b.profile.displayName);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupInfo),
        actions: [
          if (iAmAdmin)
            IconButton(
              tooltip: l10n.editGroup,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref),
            ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Stack(
              children: [
                UserAvatar(url: chat.avatarUrl, name: chat.name ?? '', radius: 56),
                if (iAmAdmin)
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      iconSize: 18,
                      onPressed: () => _changePhoto(context, ref),
                      icon: const Icon(Icons.photo_camera_rounded),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chat.name ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            l10n.membersCount(chat.members.length),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if ((chat.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(chat.description!, textAlign: TextAlign.center),
            ),
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
            child: Text(
              l10n.members,
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          if (iAmAdmin)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                child: Icon(Icons.person_add_alt_1_rounded, color: scheme.onPrimary),
              ),
              title: Text(
                l10n.addMembers,
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
              ),
              onTap: () => _addMembers(context, ref),
            ),
          for (final member in members)
            ListTile(
              leading: UserAvatar(
                url: member.profile.avatarUrl,
                name: member.profile.displayName,
                online: online.contains(member.userId),
              ),
              title: Text(member.userId == myId ? l10n.you : member.profile.displayName),
              subtitle: Text(ltrIsolate('@${member.profile.username}')),
              trailing: switch (member.role) {
                'owner' => _RoleChip(label: l10n.owner),
                'admin' => _RoleChip(label: l10n.admin),
                _ => null,
              },
              onTap: member.userId == myId ? null : () => _memberActions(context, ref, member),
            ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: scheme.error),
            title: Text(
              l10n.leaveGroup,
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
            ),
            onTap: () => _leave(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
