import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/common.dart';
import '../../profile/domain/profile.dart';
import '../data/chat_repository.dart';

class SearchUsersScreen extends ConsumerStatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  ConsumerState<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends ConsumerState<SearchUsersScreen> {
  static const _minQueryLength = 2;

  final _controller = TextEditingController();
  Timer? _debounce;
  List<Profile>? _results;
  bool _searching = false;
  String? _openingUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < _minQueryLength) {
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
        // Drop answers for a query the user has already changed.
        if (!mounted || _controller.text.trim() != query) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _searching = false);
        showErrorSnack(context, errorMessage(context.l10n, e));
      }
    });
  }

  Future<void> _open(Profile user) async {
    setState(() => _openingUserId = user.id);
    try {
      final chatId = await ref.read(chatRepositoryProvider).openDirectChat(user.id);
      if (mounted) context.pushReplacement(Routes.chat(chatId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingUserId = null);
      showErrorSnack(context, errorMessage(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        bottom: _searching
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: switch (results) {
        null => EmptyState(icon: Icons.person_search_outlined, title: l10n.searchPrompt, body: l10n.searchPromptBody),
        [] => EmptyState(icon: Icons.search_off_rounded, title: l10n.searchNoResults, body: ''),
        _ => ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final user = results[i];
            return ListTile(
              leading: UserAvatar(url: user.avatarUrl, name: user.displayName),
              title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                ltrIsolate('@${user.username}'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: _openingUserId == user.id
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_bubble_outline_rounded),
              onTap: _openingUserId == null ? () => _open(user) : null,
            );
          },
        ),
      },
    );
  }
}
