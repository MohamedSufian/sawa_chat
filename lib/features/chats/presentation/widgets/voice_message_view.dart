import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/common.dart';
import '../../application/voice_player_controller.dart';
import '../../domain/message.dart';
import '../../domain/voice.dart';

/// Voice message content: play button, seekable waveform, duration and speed.
class VoiceMessageView extends ConsumerWidget {
  const VoiceMessageView({super.key, required this.message, required this.foreground});

  final Message message;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final playback = ref.watch(voicePlayerProvider);
    final player = ref.read(voicePlayerProvider.notifier);

    final isCurrent = playback.clientId == message.clientId;
    final total = message.duration ?? (isCurrent ? playback.duration : null) ?? Duration.zero;
    final position = isCurrent ? playback.position : Duration.zero;
    final progress = total.inMilliseconds == 0 ? 0.0 : position.inMilliseconds / total.inMilliseconds;

    final uploading = message.sendStatus == SendStatus.sending && message.uploadProgress != null;
    final canPlay = message.localPath != null || message.mediaPath != null;

    Widget button;
    if (uploading) {
      button = SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(value: message.uploadProgress, strokeWidth: 3, color: foreground),
      );
    } else if (isCurrent && playback.loading) {
      button = SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3, color: foreground));
    } else {
      final playing = isCurrent && playback.playing;
      button = IconButton(
        tooltip: playing ? l10n.pause : l10n.play,
        visualDensity: VisualDensity.compact,
        iconSize: 32,
        color: foreground,
        onPressed: canPlay ? () => player.toggle(message) : null,
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      );
    }

    return SizedBox(
      width: 250,
      child: Row(
        children: [
          SizedBox.square(dimension: 44, child: Center(child: button)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SeekableWaveform(
                  bars: message.waveform,
                  progress: progress,
                  playedColor: scheme.primary,
                  pendingColor: foreground.withValues(alpha: 0.35),
                  onSeek: isCurrent ? player.seek : null,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatVoiceDuration(isCurrent && position > Duration.zero ? position : total),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.7)),
                    ),
                    const Spacer(),
                    if (isCurrent) _SpeedChip(speed: playback.speed, color: foreground, onTap: player.cycleSpeed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekableWaveform extends StatelessWidget {
  const _SeekableWaveform({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.pendingColor,
    this.onSeek,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color pendingColor;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        double fractionAt(double dx) {
          final f = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          return rtl ? 1 - f : f;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onSeek == null ? null : (d) => onSeek!(fractionAt(d.localPosition.dx)),
          onHorizontalDragUpdate: onSeek == null ? null : (d) => onSeek!(fractionAt(d.localPosition.dx)),
          child: CustomPaint(
            size: Size(constraints.maxWidth, 28),
            painter: _WaveformPainter(
              bars: bars.isEmpty ? List.filled(waveformBars, 0.15) : bars,
              progress: progress,
              playedColor: playedColor,
              pendingColor: pendingColor,
              rtl: rtl,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.pendingColor,
    required this.rtl,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color pendingColor;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars.length;
    final barWidth = slot * 0.6;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < bars.length; i++) {
      // Bars fill in the reading direction, so playback flows right-to-left in Arabic.
      final index = rtl ? bars.length - 1 - i : i;
      final x = slot * index + slot / 2;
      final height = (0.15 + bars[i] * 0.85) * size.height;
      paint.color = (i + 0.5) / bars.length <= progress ? playedColor : pendingColor;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2 + barWidth / 2),
        Offset(x, (size.height + height) / 2 - barWidth / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.bars != bars || old.playedColor != playedColor || old.rtl != rtl;
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.speed, required this.color, required this.onTap});

  final double speed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble() ? '${speed.round()}x' : '${speed}x';
    return Semantics(
      button: true,
      label: context.l10n.playbackSpeed,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
