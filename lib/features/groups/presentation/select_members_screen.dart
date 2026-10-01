import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../../chats/application/chat_list_controller.dart';
import '../../chats/data/chat_repository.dart';
import '../../profile/domain/profile.dart';

/// Multi-select people picker. Shows people you already chat with by default,
/// and searches everyone once you type. Calls [onDone] with the selection.
class SelectMembersScreen extends ConsumerStatefulWidget {
  const SelectMembersScreen({
    super.key,
    required this.title,
    required this.onDone,
    this.excludeIds = const {},
    this.doneIcon = Icons.arrow_forward_rounded,
  });

  final String title;
  final void Function(BuildContext context, List<Profile> selected) onDone;

  /// Already in the group; hidden from the list.
  final Set<String> excludeIds;
  final IconData doneIcon;

  @override
  ConsumerState<SelectMembersScreen> createState() => _SelectMembersScreenState();
}

class _SelectMembersScreenState extends ConsumerState<SelectMembersScreen> {
  final _search = TextEditingController();
  final _selected = <String, Profile>{};
  Timer? _debounce;
  List<Profile>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref.read(chatRepositoryProvider).searchUsers(query);
        if (!mounted || _search.text.trim() != query) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _toggle(Profile user) {
    setState(() => _selected.containsKey(user.id) ? _selected.remove(user.id) : _selected[user.id] = user);
  }

  void _done() {
    if (_selected.isEmpty) {
      showErrorSnack(context, context.l10n.selectAtLeastOne);
      return;
    }
    widget.onDone(context, _selected.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id)) ?? '';

    // Default suggestions: partners from existing direct chats.
    final contacts = [for (final chat in ref.watch(chatListProvider).value ?? const []) ?chat.peer(myId)];
    final people = (_results ?? contacts).where((p) => p.id != myId && !widget.excludeIds.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              l10n.selectedCount(_selected.length),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selected.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final user in _selected.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: InputChip(
                        avatar: UserAvatar(url: user.avatarUrl, name: user.displayName, radius: 12),
                        label: Text(user.displayName),
                        onDeleted: () => _toggle(user),
                      ),
                    ),
                ],
              ),
            ),
          if (_results == null && people.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.peopleYouChatWith,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ),
          Expanded(
            child: people.isEmpty
                ? EmptyState(
                    icon: Icons.person_search_outlined,
                    title: _results == null ? l10n.searchPrompt : l10n.searchNoResults,
                    body: _results == null ? l10n.searchPromptBody : '',
                  )
                : ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, i) {
                      final user = people[i];
                      final selected = _selected.containsKey(user.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(user),
                        secondary: UserAvatar(url: user.avatarUrl, name: user.displayName),
                        title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(ltrIsolate('@${user.username}')),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _done, child: Icon(widget.doneIcon)),
    );
  }
}
