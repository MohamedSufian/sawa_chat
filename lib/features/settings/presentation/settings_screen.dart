import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/json_cache.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../../blocking/blocked_users_screen.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/push_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(sessionControllerProvider).profile;
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (profile != null)
            ListTile(
              contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              leading: UserAvatar(url: profile.avatarUrl, name: profile.displayName, radius: 32),
              title: Text(
                profile.displayName,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '@${profile.username} · ${ltrIsolate(profile.phone)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          _SectionHeader(l10n.appearance),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            subtitle: Text(switch (locale?.languageCode) {
              'ar' => l10n.arabic,
              'en' => l10n.english,
              _ => l10n.languageSystem,
            }),
            onTap: () => _pick<Locale?>(
              context,
              title: l10n.language,
              current: locale,
              options: {null: l10n.languageSystem, const Locale('ar'): l10n.arabic, const Locale('en'): l10n.english},
              onSelected: ref.read(localeProvider.notifier).set,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.theme),
            subtitle: Text(switch (themeMode) {
              ThemeMode.light => l10n.themeLight,
              ThemeMode.dark => l10n.themeDark,
              ThemeMode.system => l10n.themeSystem,
            }),
            onTap: () => _pick<ThemeMode>(
              context,
              title: l10n.theme,
              current: themeMode,
              options: {
                ThemeMode.system: l10n.themeSystem,
                ThemeMode.light: l10n.themeLight,
                ThemeMode.dark: l10n.themeDark,
              },
              onSelected: ref.read(themeModeProvider.notifier).set,
            ),
          ),
          _SectionHeader(l10n.account),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(l10n.blockedUsers),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BlockedUsersScreen())),
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text(l10n.signOut, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(l10n.signOutConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.signOut)),
                  ],
                ),
              );
              if (confirmed ?? false) {
                await ref.read(pushProvider.notifier).unregister();
                await ref.read(jsonCacheProvider).clear();
                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required T current,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<T>(
          groupValue: current,
          onChanged: (value) {
            onSelected(value as T);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final entry in options.entries) RadioListTile<T>(value: entry.key, title: Text(entry.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
