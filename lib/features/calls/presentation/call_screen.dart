import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/common.dart';
import '../../chats/domain/voice.dart';
import '../application/call_session_controller.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Repaints the call timer once a second.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(callSessionProvider).phase == CallPhase.connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _status(CallSessionState s) {
    final l10n = context.l10n;
    return switch (s.phase) {
      CallPhase.outgoing => l10n.calling,
      CallPhase.incoming => s.video ? l10n.incomingVideoCall : l10n.incomingAudioCall,
      CallPhase.connecting => l10n.connecting,
      CallPhase.connected => formatVoiceDuration(DateTime.now().difference(s.connectedAt ?? DateTime.now())),
      CallPhase.ended || CallPhase.idle => switch (s.endReason) {
        CallEndReason.declined => l10n.callDeclined,
        CallEndReason.busy => l10n.callBusy,
        CallEndReason.noAnswer => l10n.callNoAnswer,
        CallEndReason.failed => l10n.callFailed,
        _ => l10n.callEnded,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(callSessionProvider);
    final controller = ref.read(callSessionProvider.notifier);

    // The session goes idle shortly after a call ends: close the screen.
    ref.listen(callSessionProvider.select((s) => s.phase), (_, phase) {
      if (phase == CallPhase.idle && context.canPop()) context.pop();
    });

    final showRemoteVideo = s.video && s.phase == CallPhase.connected;
    final showLocalVideo = s.video && !s.cameraOff && s.active;
    final peerName = s.peer?.displayName ?? '';

    return PopScope(
      // Leaving the screen mid-call would orphan the call; use the end button.
      canPop: !s.active,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1F1D),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (showRemoteVideo)
              RTCVideoView(controller.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E9F8E), Color(0xFF0B1F1D)],
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  if (!showRemoteVideo) ...[
                    UserAvatar(url: s.peer?.avatarUrl, name: peerName, radius: 64),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    peerName,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status(s),
                    textDirection: s.phase == CallPhase.connected ? TextDirection.ltr : null,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),
                  if (s.phase == CallPhase.incoming)
                    _IncomingActions(onAccept: controller.accept, onDecline: controller.decline)
                  else if (s.active)
                    _InCallControls(state: s, controller: controller),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (showLocalVideo)
              PositionedDirectional(
                top: MediaQuery.paddingOf(context).top + 16,
                end: 16,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(
                    controller.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: l10n.decline,
          color: const Color(0xFFE53935),
          onTap: onDecline,
        ),
        _RoundButton(icon: Icons.call_rounded, label: l10n.accept, color: const Color(0xFF22C55E), onTap: onAccept),
      ],
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({required this.state, required this.controller});

  final CallSessionState state;
  final CallSessionController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 20,
      children: [
        _RoundButton(
          icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: l10n.mute,
          selected: state.muted,
          onTap: controller.toggleMute,
        ),
        if (state.video) ...[
          _RoundButton(
            icon: state.cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: l10n.cameraLabel,
            selected: state.cameraOff,
            onTap: controller.toggleCamera,
          ),
          _RoundButton(icon: Icons.cameraswitch_rounded, label: l10n.flipCamera, onTap: controller.switchCamera),
        ],
        _RoundButton(
          icon: state.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
          label: l10n.speaker,
          selected: state.speakerOn,
          onTap: controller.toggleSpeaker,
        ),
        _RoundButton(
          icon: Icons.call_end_rounded,
          label: l10n.endCall,
          color: const Color(0xFFE53935),
          onTap: controller.hangUp,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.color, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = color ?? (selected ? Colors.white : Colors.white24);
    final foreground = color != null ? Colors.white : (selected ? Colors.black87 : Colors.white);
    return Semantics(
      button: true,
      toggled: color == null ? selected : null,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(dimension: 64, child: Icon(icon, color: foreground, size: 28)),
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
