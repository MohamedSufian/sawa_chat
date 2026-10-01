import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../../chats/domain/voice.dart';
import '../application/call_session_controller.dart';
import '../data/call_repository.dart';
import '../domain/call.dart';

/// Call log, refreshed whenever one of my calls changes.
final callHistoryProvider = AsyncNotifierProvider.autoDispose<CallHistoryController, List<CallRecord>>(
  CallHistoryController.new,
);

class CallHistoryController extends AsyncNotifier<List<CallRecord>> {
  Timer? _debounce;

  @override
  Future<List<CallRecord>> build() async {
    ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
    final repo = ref.watch(callRepositoryProvider);
    final channel = repo.watchAll(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), refresh);
    });
    ref.onDispose(() {
      _debounce?.cancel();
      repo.unsubscribe(channel);
    });
    return repo.history();
  }

  Future<void> refresh() async {
    final result = await AsyncValue.guard(ref.read(callRepositoryProvider).history);
    if (ref.mounted && (result.hasValue || !state.hasValue)) state = result;
  }
}

class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final calls = ref.watch(callHistoryProvider);
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id)) ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calls)),
      body: switch (calls) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.call_outlined,
          title: l10n.noCallsTitle,
          body: l10n.noCallsBody,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: ref.read(callHistoryProvider.notifier).refresh,
          child: ListView.builder(
            itemCount: value.length,
            itemBuilder: (context, i) => _CallTile(call: value[i], myId: myId),
          ),
        ),
        AsyncError() => Center(
          child: OutlinedButton(onPressed: () => ref.invalidate(callHistoryProvider), child: Text(l10n.retry)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _CallTile extends ConsumerWidget {
  const _CallTile({required this.call, required this.myId});

  final CallRecord call;
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peer = call.peer(myId);
    final missed = call.isMissedBy(myId);
    final outgoing = call.isOutgoing(myId);
    final talk = call.talkTime;

    final details = [chatListTime(context, call.createdAt), if (talk != null) formatVoiceDuration(talk)].join(' · ');

    return ListTile(
      leading: UserAvatar(url: peer?.avatarUrl, name: peer?.displayName ?? '', radius: 24),
      title: Text(
        peer?.displayName ?? '',
        style: TextStyle(fontWeight: FontWeight.w700, color: missed ? scheme.error : null),
      ),
      subtitle: Row(
        children: [
          Icon(
            missed
                ? Icons.call_missed_rounded
                : outgoing
                ? Icons.call_made_rounded
                : Icons.call_received_rounded,
            size: 16,
            color: missed ? scheme.error : scheme.primary,
            semanticLabel: missed
                ? l10n.missedCall
                : outgoing
                ? l10n.outgoingCall
                : l10n.incomingCall,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
      trailing: peer == null
          ? null
          : IconButton(
              tooltip: call.isVideo ? l10n.videoCall : l10n.audioCall,
              icon: Icon(call.isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: scheme.primary),
              onPressed: () => ref.read(callSessionProvider.notifier).startOutgoing(peer, video: call.isVideo),
            ),
    );
  }
}
