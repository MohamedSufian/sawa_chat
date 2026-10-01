import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/features/chats/domain/voice.dart';

void main() {
  group('downsampleWaveform', () {
    test('always returns the requested number of bars', () {
      expect(downsampleWaveform([], bars: 48), hasLength(48));
      expect(downsampleWaveform([0.5, 0.5, 0.5], bars: 48), hasLength(48));
      expect(downsampleWaveform(List.filled(3000, 0.2), bars: 48), hasLength(48));
    });

    test('averages buckets and scales to 0..100', () {
      expect(downsampleWaveform([0, 1, 0, 1], bars: 2), [50, 50]);
      expect(downsampleWaveform([1, 1, 0, 0], bars: 2), [100, 0]);
    });

    test('stretches short recordings instead of padding with silence', () {
      expect(downsampleWaveform([1.0], bars: 4), [100, 100, 100, 100]);
    });
  });

  test('normalizeDbfs maps silence to 0 and loud speech to 1', () {
    expect(normalizeDbfs(-160), 0);
    expect(normalizeDbfs(-50), 0);
    expect(normalizeDbfs(0), 1);
    expect(normalizeDbfs(-27.5), closeTo(0.5, 1e-9));
  });

  test('formatVoiceDuration', () {
    expect(formatVoiceDuration(const Duration(seconds: 7)), '0:07');
    expect(formatVoiceDuration(const Duration(minutes: 1, seconds: 23)), '1:23');
  });
}
