import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/media_repository.dart';
import '../domain/message.dart';

class VoicePlaybackState {
  const VoicePlaybackState({
    this.clientId,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1,
  });

  /// Message currently loaded in the player, if any.
  final String? clientId;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration? duration;
  final double speed;

  VoicePlaybackState copyWith({
    String? clientId,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    double? speed,
  }) => VoicePlaybackState(
    clientId: clientId ?? this.clientId,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
  );
}

/// A single audio player shared by every voice bubble on screen, so starting
/// one message stops the previous one. Disposed when the chat closes.
final voicePlayerProvider = NotifierProvider.autoDispose<VoicePlayerController, VoicePlaybackState>(
  VoicePlayerController.new,
);

class VoicePlayerController extends Notifier<VoicePlaybackState> {
  static const speeds = [1.0, 1.5, 2.0];

  late AudioPlayer _player;

  @override
  VoicePlaybackState build() {
    _player = AudioPlayer();
    final subs = <StreamSubscription<dynamic>>[
      _player.positionStream.listen((p) => state = state.copyWith(position: p)),
      _player.durationStream.listen((d) {
        if (d != null) state = state.copyWith(duration: d);
      }),
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          // Rewind so the next tap plays from the start.
          _player.pause();
          _player.seek(Duration.zero);
          state = state.copyWith(playing: false, position: Duration.zero);
        } else {
          state = state.copyWith(
            playing: s.playing,
            loading: s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering,
          );
        }
      }),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
      _player.dispose();
    });
    return const VoicePlaybackState();
  }

  Future<void> toggle(Message message) async {
    if (state.clientId == message.clientId) {
      return state.playing ? _player.pause() : _player.play();
    }

    state = VoicePlaybackState(
      clientId: message.clientId,
      loading: true,
      duration: message.duration,
      speed: state.speed,
    );
    try {
      if (message.localPath != null) {
        await _player.setFilePath(message.localPath!);
      } else {
        final url = await ref.read(mediaUrlProvider(message.mediaPath!).future);
        await _player.setUrl(url);
      }
      if (!ref.mounted || state.clientId != message.clientId) return;
      await _player.setSpeed(state.speed);
      unawaited(_player.play());
    } catch (_) {
      if (ref.mounted) state = const VoicePlaybackState();
    }
  }

  /// [fraction] 0..1 of the message currently loaded.
  Future<void> seek(double fraction) async {
    final total = state.duration;
    if (total == null) return;
    await _player.seek(total * fraction.clamp(0.0, 1.0));
  }

  Future<void> cycleSpeed() async {
    final next = speeds[(speeds.indexOf(state.speed) + 1) % speeds.length];
    state = state.copyWith(speed: next);
    await _player.setSpeed(next);
  }
}
