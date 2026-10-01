import 'message.dart';

enum GroupEventType { created, added, removed, left, renamed, photoChanged, promoted, demoted, unknown }

/// A group change recorded as a `system` message (see migration 0003).
class GroupEvent {
  const GroupEvent({required this.type, required this.actorId, this.targetIds = const [], this.name});

  final GroupEventType type;
  final String? actorId;
  final List<String> targetIds;

  /// New group name, for `created` and `renamed`.
  final String? name;

  static GroupEvent? fromMessage(Message message) {
    if (message.type != MessageType.system) return null;
    final meta = message.mediaMeta ?? const {};
    return GroupEvent(
      type: switch (meta['event']) {
        'created' => GroupEventType.created,
        'added' => GroupEventType.added,
        'removed' => GroupEventType.removed,
        'left' => GroupEventType.left,
        'renamed' => GroupEventType.renamed,
        'photo_changed' => GroupEventType.photoChanged,
        'promoted' => GroupEventType.promoted,
        'demoted' => GroupEventType.demoted,
        _ => GroupEventType.unknown,
      },
      actorId: message.senderId,
      targetIds: [for (final t in meta['targets'] as List<dynamic>? ?? const []) t as String],
      name: meta['name'] as String?,
    );
  }
}
