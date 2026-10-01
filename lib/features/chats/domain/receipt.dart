enum ReceiptStatus { sent, delivered, read }

/// How far one member has received and read a chat (a pair of watermarks).
class MemberReceipt {
  const MemberReceipt({required this.userId, required this.lastDeliveredAt, required this.lastReadAt});

  final String userId;
  final DateTime lastDeliveredAt;
  final DateTime lastReadAt;

  factory MemberReceipt.fromJson(Map<String, dynamic> json) => MemberReceipt(
    userId: json['user_id'] as String,
    lastDeliveredAt: DateTime.parse(json['last_delivered_at'] as String),
    lastReadAt: DateTime.parse(json['last_read_at'] as String),
  );
}

/// A message is read (or delivered) once every *other* member's watermark has passed it.
/// Works the same for direct chats and groups.
ReceiptStatus receiptStatus(DateTime sentAt, Iterable<MemberReceipt> others) {
  if (others.isEmpty) return ReceiptStatus.sent;
  if (others.every((r) => !r.lastReadAt.isBefore(sentAt))) return ReceiptStatus.read;
  if (others.every((r) => !r.lastDeliveredAt.isBefore(sentAt))) return ReceiptStatus.delivered;
  return ReceiptStatus.sent;
}
