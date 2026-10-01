import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/error_message.dart';
import '../../core/widgets/common.dart';
import 'blocked_users_controller.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blocked = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsers)),
      body: switch (blocked) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.block_outlined,
          title: l10n.noBlockedUsers,
          body: '',
        ),
        AsyncData(:final value) => ListView(
          children: [
            for (final user in value)
              ListTile(
                leading: UserAvatar(url: user.avatarUrl, name: user.displayName),
                title: Text(user.displayName),
                subtitle: Text(ltrIsolate('@${user.username}')),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(blockedUsersProvider.notifier).unblock(user.id);
                    } catch (e) {
                      if (context.mounted) showErrorSnack(context, errorMessage(context.l10n, e));
                    }
                  },
                  child: Text(l10n.unblockUser),
                ),
              ),
          ],
        ),
        AsyncError() => Center(
          child: OutlinedButton(onPressed: () => ref.invalidate(blockedUsersProvider), child: Text(l10n.retry)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
