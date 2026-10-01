import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/features/chats/domain/chat.dart';
import 'package:sawa_chat/features/chats/domain/message.dart';
import 'package:sawa_chat/l10n/app_localizations_en.dart';
import 'package:sawa_chat/features/chats/presentation/message_preview.dart';

Map<String, dynamic> _profile(String id, String name) => {
  'id': id,
  'phone': '+970599000001',
  'username': name.toLowerCase(),
  'display_name': name,
  'bio': null,
  'avatar_url': null,
  'last_seen_at': '2026-09-28T10:00:00Z',
};

Map<String, dynamic> _member(String id, String name) => {
  'user_id': id,
  'role': 'member',
  'last_read_at': '2026-09-28T10:00:00Z',
  'last_delivered_at': '2026-09-28T10:00:00Z',
  'muted': false,
  'profile': _profile(id, name),
};

Map<String, dynamic> _message({String type = 'text', String? content = 'Hello', bool deleted = false}) => {
  'id': 'm1',
  'client_id': 'c1',
  'chat_id': 'chat1',
  'sender_id': 'me',
  'type': type,
  'content': content,
  'media_path': null,
  'media_meta': null,
  'reply_to_id': null,
  'deleted_for_everyone': deleted,
  'created_at': '2026-09-28T10:05:00Z',
};

void main() {
  test('direct chat shows the other member as title', () {
    final chat = Chat.fromJson({
      'id': 'chat1',
      'type': 'direct',
      'name': null,
      'avatar_url': null,
      'last_message': _message(),
      'last_message_at': '2026-09-28T10:05:00Z',
      'created_at': '2026-09-28T09:00:00Z',
      'members': [_member('me', 'Me'), _member('them', 'Lina')],
    });

    expect(chat.title('me'), 'Lina');
    expect(chat.peer('me')?.id, 'them');
    expect(chat.lastMessage?.content, 'Hello');
    expect(chat.sortTime, DateTime.parse('2026-09-28T10:05:00Z'));
  });

  test('image aspect ratio comes from media_meta', () {
    final json = _message(type: 'image', content: null)..['media_meta'] = {'width': 1600, 'height': 1200};
    expect(Message.fromJson(json).aspectRatio, closeTo(4 / 3, 1e-9));
    expect(Message.fromJson(_message()).aspectRatio, isNull);
  });

  group('messagePreview', () {
    final l10n = AppLocalizationsEn();

    test('prefixes my own messages', () {
      expect(messagePreview(l10n, Message.fromJson(_message()), mine: true), 'You: Hello');
      expect(messagePreview(l10n, Message.fromJson(_message()), mine: false), 'Hello');
    });

    test('describes media and deleted messages', () {
      expect(messagePreview(l10n, Message.fromJson(_message(type: 'image', content: null)), mine: false), '📷 Photo');
      expect(messagePreview(l10n, Message.fromJson(_message(deleted: true)), mine: false), 'This message was deleted');
    });
  });
}
