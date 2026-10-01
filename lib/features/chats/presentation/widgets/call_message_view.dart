import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/common.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/message.dart';
import '../../domain/voice.dart';

/// "Voice call · 2:31", "Video call · No answer", "Missed call".
/// [mine] means I was the caller (call messages are sent as the caller).
String callSummary(AppLocalizations l10n, Message message, {required bool mine}) {
  final meta = message.mediaMeta ?? const {};
  final kind = meta['kind'] == 'video' ? l10n.videoCall : l10n.audioCall;
  final seconds = (meta['duration_s'] as num?)?.toInt() ?? 0;
  return switch (meta['status']) {
    'ended' => '$kind · ${formatVoiceDuration(Duration(seconds: seconds))}',
    'declined' => '$kind · ${l10n.callDeclined}',
    'busy' when mine => '$kind · ${l10n.callBusy}',
    _ when mine => '$kind · ${l10n.callNoAnswer}',
    _ => l10n.missedCall,
  };
}

bool _isMissed(Message m, bool mine) => !mine && !const {'ended', 'declined'}.contains(m.mediaMeta?['status']);

class CallMessageView extends StatelessWidget {
  const CallMessageView({super.key, required this.message, required this.mine, required this.foreground});

  final Message message;
  final bool mine;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final missed = _isMissed(message, mine);
    final video = message.mediaMeta?['kind'] == 'video';
    final color = missed ? Theme.of(context).colorScheme.error : foreground;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            missed
                ? Icons.call_missed_rounded
                : video
                ? Icons.videocam_rounded
                : Icons.call_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            callSummary(context.l10n, message, mine: mine),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
