import 'package:flutter_test/flutter_test.dart';
import 'package:sawa_chat/features/chats/domain/receipt.dart';

MemberReceipt _r(String id, {required int deliveredMin, required int readMin}) => MemberReceipt(
  userId: id,
  lastDeliveredAt: DateTime.utc(2026, 9, 28, 10, deliveredMin),
  lastReadAt: DateTime.utc(2026, 9, 28, 10, readMin),
);

void main() {
  final sentAt = DateTime.utc(2026, 9, 28, 10, 5);

  test('no other members means just sent', () {
    expect(receiptStatus(sentAt, const []), ReceiptStatus.sent);
  });

  test('direct chat moves sent → delivered → read', () {
    expect(receiptStatus(sentAt, [_r('b', deliveredMin: 4, readMin: 4)]), ReceiptStatus.sent);
    expect(receiptStatus(sentAt, [_r('b', deliveredMin: 5, readMin: 4)]), ReceiptStatus.delivered);
    expect(receiptStatus(sentAt, [_r('b', deliveredMin: 6, readMin: 6)]), ReceiptStatus.read);
  });

  test('group is only read once every member has read', () {
    final someRead = [_r('b', deliveredMin: 6, readMin: 6), _r('c', deliveredMin: 6, readMin: 1)];
    expect(receiptStatus(sentAt, someRead), ReceiptStatus.delivered);

    final oneOffline = [_r('b', deliveredMin: 6, readMin: 6), _r('c', deliveredMin: 1, readMin: 1)];
    expect(receiptStatus(sentAt, oneOffline), ReceiptStatus.sent);
  });
}
