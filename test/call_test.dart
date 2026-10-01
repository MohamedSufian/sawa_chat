import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/features/calls/domain/call.dart';
import 'package:sawa_chat/features/chats/domain/message.dart';
import 'package:sawa_chat/features/chats/presentation/widgets/call_message_view.dart';
import 'package:sawa_chat/l10n/app_localizations_en.dart';

CallRecord _call(String status, {String caller = 'me', bool answered = false}) => CallRecord.fromJson({
  'id': 'c1',
  'chat_id': 'chat',
  'caller_id': caller,
  'callee_id': caller == 'me' ? 'them' : 'me',
  'kind': 'audio',
  'status': status,
  'created_at': '2026-10-01T10:00:00Z',
  'answered_at': answered ? '2026-10-01T10:00:05Z' : null,
  'ended_at': '2026-10-01T10:02:36Z',
});

Message _callMessage(String status, {String kind = 'audio', int seconds = 0}) => Message(
  clientId: 'm',
  chatId: 'chat',
  senderId: 'caller',
  type: MessageType.call,
  mediaMeta: {'kind': kind, 'status': status, 'duration_s': seconds},
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  group('CallRecord', () {
    test('only unanswered incoming calls count as missed', () {
      expect(_call('missed', caller: 'them').isMissedBy('me'), isTrue);
      expect(_call('cancelled', caller: 'them').isMissedBy('me'), isTrue);
      expect(_call('declined', caller: 'them').isMissedBy('me'), isFalse);
      expect(_call('missed').isMissedBy('me'), isFalse, reason: 'my own outgoing call');
    });

    test('talk time runs from answer to end', () {
      expect(_call('ended', answered: true).talkTime, const Duration(minutes: 2, seconds: 31));
      expect(_call('missed').talkTime, isNull);
    });
  });

  group('callSummary', () {
    final l10n = AppLocalizationsEn();

    test('answered calls show their length to both sides', () {
      final m = _callMessage('ended', seconds: 151);
      expect(callSummary(l10n, m, mine: true), 'Voice call · 2:31');
      expect(callSummary(l10n, m, mine: false), 'Voice call · 2:31');
    });

    test('unanswered calls read differently for caller and callee', () {
      final m = _callMessage('missed', kind: 'video');
      expect(callSummary(l10n, m, mine: true), 'Video call · No answer');
      expect(callSummary(l10n, m, mine: false), 'Missed call');
    });
  });
}
