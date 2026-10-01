import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/core/widgets/common.dart';
import 'package:sawa_chat/features/profile/data/profile_repository.dart';

void main() {
  group('username pattern', () {
    final pattern = ProfileRepository.usernamePattern;

    test('accepts lowercase letters, digits and underscore', () {
      expect(pattern.hasMatch('sawa_user1'), isTrue);
      expect(pattern.hasMatch('abc'), isTrue);
    });

    test('rejects too short, too long, uppercase and symbols', () {
      expect(pattern.hasMatch('ab'), isFalse);
      expect(pattern.hasMatch('a' * 21), isFalse);
      expect(pattern.hasMatch('Sawa'), isFalse);
      expect(pattern.hasMatch('sawa.chat'), isFalse);
      expect(pattern.hasMatch('سوا'), isFalse);
    });
  });

  test('ltrIsolate wraps text in LRI/PDI marks', () {
    final result = ltrIsolate('+970599123456');
    expect(result.codeUnitAt(0), 0x2066);
    expect(result.codeUnitAt(result.length - 1), 0x2069);
    expect(result.substring(1, result.length - 1), '+970599123456');
  });
}
