import '../../profile/domain/profile.dart';
import 'message.dart';
import 'receipt.dart';

class ChatMember {
  const ChatMember({
    required this.userId,
    required this.role,
    required this.lastReadAt,
    required this.lastDeliveredAt,
    required this.muted,
    required this.profile,
  });

  final String userId;
  final String role;
  final DateTime lastReadAt;
  final DateTime lastDeliveredAt;
  final bool muted;
  final Profile profile;

  MemberReceipt get receipt => MemberReceipt(userId: userId, lastDeliveredAt: lastDeliveredAt, lastReadAt: lastReadAt);

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    userId: json['user_id'] as String,
    role: json['role'] as String,
    lastReadAt: DateTime.parse(json['last_read_at'] as String),
    lastDeliveredAt: DateTime.parse(json['last_delivered_at'] as String),
    muted: json['muted'] as bool,
    profile: Profile.fromJson(json['profile'] as Map<String, dynamic>),
  );
}

class Chat {
  const Chat({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    required this.members,
    this.unreadCount = 0,
  });

  final String id;
  final String type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final Message? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final List<ChatMember> members;
  final int unreadCount;

  bool get isDirect => type == 'direct';
  bool get isGroup => type == 'group';

  ChatMember? member(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  bool isAdmin(String userId) => const {'owner', 'admin'}.contains(member(userId)?.role);

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'] as String,
    type: json['type'] as String,
    name: json['name'] as String?,
    description: json['description'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastMessage: json['last_message'] == null ? null : Message.fromJson(json['last_message'] as Map<String, dynamic>),
    lastMessageAt: json['last_message_at'] == null ? null : DateTime.parse(json['last_message_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    members: (json['members'] as List<dynamic>).map((m) => ChatMember.fromJson(m as Map<String, dynamic>)).toList(),
    unreadCount: json['unread_count'] as int? ?? 0,
  );

  /// The other person in a direct chat.
  Profile? peer(String myId) {
    if (!isDirect) return null;
    for (final m in members) {
      if (m.userId != myId) return m.profile;
    }
    return null;
  }

  String title(String myId) => isDirect ? (peer(myId)?.displayName ?? '') : (name ?? '');

  String? avatar(String myId) => isDirect ? peer(myId)?.avatarUrl : avatarUrl;

  DateTime get sortTime => lastMessageAt ?? createdAt;

  ReceiptStatus receiptFor(Message message, String myId) => receiptStatus(message.createdAt, [
    for (final m in members)
      if (m.userId != myId) m.receipt,
  ]);
}
