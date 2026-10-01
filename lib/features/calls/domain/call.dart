import '../../profile/domain/profile.dart';

enum CallStatus { ringing, accepted, declined, missed, busy, cancelled, ended }

class CallRecord {
  const CallRecord({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.calleeId,
    required this.isVideo,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.caller,
    this.callee,
  });

  final String id;
  final String? chatId;
  final String callerId;
  final String calleeId;
  final bool isVideo;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// Present when fetched for the call history.
  final Profile? caller;
  final Profile? callee;

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: json['id'] as String,
    chatId: json['chat_id'] as String?,
    callerId: json['caller_id'] as String,
    calleeId: json['callee_id'] as String,
    isVideo: json['kind'] == 'video',
    status: CallStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    answeredAt: json['answered_at'] == null ? null : DateTime.parse(json['answered_at'] as String),
    endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
    caller: json['caller'] == null ? null : Profile.fromJson(json['caller'] as Map<String, dynamic>),
    callee: json['callee'] == null ? null : Profile.fromJson(json['callee'] as Map<String, dynamic>),
  );

  bool isOutgoing(String myId) => callerId == myId;

  Profile? peer(String myId) => isOutgoing(myId) ? callee : caller;

  String peerId(String myId) => isOutgoing(myId) ? calleeId : callerId;

  /// An incoming call I never picked up.
  bool isMissedBy(String myId) =>
      !isOutgoing(myId) && const {CallStatus.missed, CallStatus.cancelled, CallStatus.busy}.contains(status);

  Duration? get talkTime => (answeredAt != null && endedAt != null) ? endedAt!.difference(answeredAt!) : null;
}
