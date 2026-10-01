import 'dart:typed_data';

enum MessageType { text, image, voice, system, call }

/// Local-only delivery state of a message this device is sending.
enum SendStatus { sending, sent, failed }

class Message {
  const Message({
    this.id,
    required this.clientId,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaPath,
    this.mediaMeta,
    this.replyToId,
    this.deletedForEveryone = false,
    required this.createdAt,
    this.sendStatus = SendStatus.sent,
    this.localBytes,
    this.localPath,
    this.uploadProgress,
  });

  /// Server id; null until the insert succeeds.
  final String? id;

  /// Device-generated id, stable from the optimistic bubble to the stored row.
  final String clientId;
  final String chatId;
  final String? senderId;
  final MessageType type;
  final String? content;

  /// Object path inside the `chat-media` bucket; set once the upload finished.
  final String? mediaPath;
  final Map<String, dynamic>? mediaMeta;
  final String? replyToId;
  final bool deletedForEveryone;
  final DateTime createdAt;
  final SendStatus sendStatus;

  /// Compressed media kept in memory on the sending device, so the bubble shows
  /// instantly and a failed upload can be retried without re-encoding.
  final Uint8List? localBytes;

  /// Recorded file on the sending device (voice messages), playable before upload.
  final String? localPath;

  /// 0..1 while uploading, null otherwise.
  final double? uploadProgress;

  /// Length of a voice message.
  Duration? get duration {
    final ms = (mediaMeta?['duration_ms'] as num?)?.toInt();
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// Normalised 0..1 bar heights recorded with a voice message.
  List<double> get waveform => [
    for (final v in (mediaMeta?['waveform'] as List<dynamic>? ?? const [])) ((v as num) / 100).clamp(0.0, 1.0),
  ];

  /// Width / height of an image, used to reserve space before it loads.
  double? get aspectRatio {
    final w = (mediaMeta?['width'] as num?)?.toDouble();
    final h = (mediaMeta?['height'] as num?)?.toDouble();
    return (w == null || h == null || h == 0) ? null : w / h;
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    clientId: json['client_id'] as String,
    chatId: json['chat_id'] as String,
    senderId: json['sender_id'] as String?,
    type: MessageType.values.byName(json['type'] as String),
    content: json['content'] as String?,
    mediaPath: json['media_path'] as String?,
    mediaMeta: json['media_meta'] as Map<String, dynamic>?,
    replyToId: json['reply_to_id'] as String?,
    deletedForEveryone: json['deleted_for_everyone'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Message copyWith({
    SendStatus? sendStatus,
    String? mediaPath,
    Uint8List? localBytes,
    String? localPath,
    double? uploadProgress,
    bool clearProgress = false,
  }) => Message(
    id: id,
    clientId: clientId,
    chatId: chatId,
    senderId: senderId,
    type: type,
    content: content,
    mediaPath: mediaPath ?? this.mediaPath,
    mediaMeta: mediaMeta,
    replyToId: replyToId,
    deletedForEveryone: deletedForEveryone,
    createdAt: createdAt,
    sendStatus: sendStatus ?? this.sendStatus,
    localBytes: localBytes ?? this.localBytes,
    localPath: localPath ?? this.localPath,
    uploadProgress: clearProgress ? null : (uploadProgress ?? this.uploadProgress),
  );
}
