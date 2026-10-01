import 'dart:math' as math;

class VoiceRecording {
  const VoiceRecording({required this.path, required this.duration, required this.waveform});

  final String path;
  final Duration duration;

  /// Bar heights 0..100, ready to store in `media_meta`.
  final List<int> waveform;
}

/// Number of bars stored per voice message, whatever its length.
const waveformBars = 48;

/// Maps a dBFS amplitude (≈ -160 silence … 0 max) to 0..1.
/// Speech sits roughly between -50 and -5 dBFS, so that range fills the bar.
double normalizeDbfs(double dbfs) => ((dbfs + 50) / 45).clamp(0.0, 1.0);

/// Resamples raw 0..1 amplitude samples into exactly [bars] values of 0..100.
/// Averages when there are more samples than bars, stretches when fewer.
List<int> downsampleWaveform(List<double> samples, {int bars = waveformBars}) {
  if (samples.isEmpty) return List.filled(bars, 0);

  final result = <int>[];
  for (var i = 0; i < bars; i++) {
    final start = (i * samples.length / bars).floor();
    final end = math.max(start + 1, ((i + 1) * samples.length / bars).floor());
    final bucket = samples.sublist(start, math.min(end, samples.length));
    final average = bucket.reduce((a, b) => a + b) / bucket.length;
    result.add((average * 100).round().clamp(0, 100));
  }
  return result;
}

/// "0:07", "1:23", "12:05".
String formatVoiceDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
