import '../../../l10n/app_localizations.dart';
import '../domain/system_event.dart';

/// Turns a stored group event into a sentence in the reader's language.
/// Uses dedicated phrasings when the reader is the actor or the only target,
/// so Arabic reads naturally ("أضفتَ…", "…أضافك") instead of "أنت أضاف".
String describeGroupEvent(
  AppLocalizations l10n,
  GroupEvent event, {
  required String myId,
  required String Function(String userId) nameOf,
}) {
  final byMe = event.actorId == myId;
  final actor = event.actorId == null ? l10n.someone : nameOf(event.actorId!);
  final onlyMe = event.targetIds.length == 1 && event.targetIds.single == myId;
  final separator = l10n.localeName.startsWith('ar') ? '، ' : ', ';
  final targets = event.targetIds.map((id) => id == myId ? l10n.you : nameOf(id)).join(separator);
  final name = event.name ?? '';

  return switch (event.type) {
    GroupEventType.created => byMe ? l10n.evCreatedYou(name) : l10n.evCreated(actor, name),
    GroupEventType.added =>
      byMe
          ? l10n.evAddedYou(targets)
          : onlyMe
          ? l10n.evAddedMe(actor)
          : l10n.evAdded(actor, targets),
    GroupEventType.removed =>
      byMe
          ? l10n.evRemovedYou(targets)
          : onlyMe
          ? l10n.evRemovedMe(actor)
          : l10n.evRemoved(actor, targets),
    GroupEventType.left => byMe ? l10n.evLeftYou : l10n.evLeft(actor),
    GroupEventType.renamed => byMe ? l10n.evRenamedYou(name) : l10n.evRenamed(actor, name),
    GroupEventType.photoChanged => byMe ? l10n.evPhotoYou : l10n.evPhoto(actor),
    GroupEventType.promoted =>
      byMe
          ? l10n.evPromotedYou(targets)
          : onlyMe
          ? l10n.evPromotedMe(actor)
          : l10n.evPromoted(actor, targets),
    GroupEventType.demoted =>
      byMe
          ? l10n.evDemotedYou(targets)
          : onlyMe
          ? l10n.evDemotedMe(actor)
          : l10n.evDemoted(actor, targets),
    GroupEventType.unknown => '',
  };
}
