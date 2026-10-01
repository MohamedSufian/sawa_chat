import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/features/chats/domain/message.dart';
import 'package:sawa_chat/features/chats/domain/system_event.dart';
import 'package:sawa_chat/features/chats/presentation/group_event_text.dart';
import 'package:sawa_chat/l10n/app_localizations_ar.dart';
import 'package:sawa_chat/l10n/app_localizations_en.dart';

Message _system(String actor, String event, {List<String> targets = const [], String? name}) => Message(
  clientId: 'c',
  chatId: 'g',
  senderId: actor,
  type: MessageType.system,
  mediaMeta: {'event': event, 'targets': targets, 'name': ?name},
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  const names = {'me': 'Me', 'ahmad': 'Ahmad', 'lina': 'Lina', 'sara': 'Sara'};
  String nameOf(String id) => names[id] ?? '?';
  String en(Message m) =>
      describeGroupEvent(AppLocalizationsEn(), GroupEvent.fromMessage(m)!, myId: 'me', nameOf: nameOf);
  String ar(Message m) =>
      describeGroupEvent(AppLocalizationsAr(), GroupEvent.fromMessage(m)!, myId: 'me', nameOf: nameOf);

  test('non-system messages are not events', () {
    final text = Message(
      clientId: 'c',
      chatId: 'g',
      senderId: 'x',
      type: MessageType.text,
      createdAt: DateTime.utc(2026),
    );
    expect(GroupEvent.fromMessage(text), isNull);
  });

  test('third-person events list every target', () {
    expect(en(_system('ahmad', 'added', targets: ['lina', 'sara'])), 'Ahmad added Lina, Sara');
    expect(ar(_system('ahmad', 'added', targets: ['lina', 'sara'])), 'Ahmad أضاف Lina، Sara');
  });

  test('uses first-person phrasing when I am the actor', () {
    expect(en(_system('me', 'created', name: 'Team')), 'You created the group "Team"');
    expect(ar(_system('me', 'left')), 'غادرتَ المجموعة');
  });

  test('uses "you" object phrasing when I am the only target', () {
    expect(en(_system('ahmad', 'added', targets: ['me'])), 'Ahmad added you');
    expect(ar(_system('ahmad', 'promoted', targets: ['me'])), 'Ahmad عيّنك مشرفًا');
  });

  test('unknown events render as empty text instead of crashing', () {
    expect(en(_system('ahmad', 'something_new')), '');
  });
}
