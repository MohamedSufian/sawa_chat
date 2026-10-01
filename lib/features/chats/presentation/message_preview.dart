import '../../../l10n/app_localizations.dart';
import '../domain/message.dart';

/// One-line summary of a message for the chat list.
///
/// [senderName] prefixes other people's messages in groups; [systemText] is
/// the already-described group event for system messages.
String messagePreview(
  AppLocalizations l10n,
  Message message, {
  required bool mine,
  String? senderName,
  String? systemText,
}) {
  if (message.type == MessageType.system) return systemText ?? '';
  if (message.type == MessageType.call) {
    return message.mediaMeta?['kind'] == 'video' ? '🎥 ${l10n.videoCall}' : '📞 ${l10n.audioCall}';
  }

  final body = message.deletedForEveryone
      ? l10n.messageDeleted
      : switch (message.type) {
          MessageType.image => '📷 ${l10n.photo}',
          MessageType.voice => '🎤 ${l10n.voiceMessage}',
          _ => (message.content ?? '').replaceAll('\n', ' '),
        };
  final prefix = mine ? l10n.you : senderName;
  return prefix == null ? body : '$prefix: $body';
}
