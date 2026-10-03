import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/message.dart';
import '../../domain/receipt.dart';
import 'call_message_view.dart';
import 'chat_image.dart';
import 'voice_message_view.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.tail,
    this.receipt = ReceiptStatus.sent,
    this.senderName,
    this.onRetry,
  });

  final Message message;
  final bool mine;

  /// Last bubble in a run from the same sender: gets extra spacing and a pointed corner.
  final bool tail;

  /// Delivered/read state of my stored messages; ignored while sending or failed.
  final ReceiptStatus receipt;

  /// Shown above the first bubble of a run in groups.
  final String? senderName;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    final background = mine ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final metaColor = foreground.withValues(alpha: 0.65);

    final deleted = message.deletedForEveryone;
    final text = deleted ? l10n.messageDeleted : (message.content ?? '');
    final isImage = message.type == MessageType.image && !deleted;
    final isVoice = message.type == MessageType.voice && !deleted;
    final isCall = message.type == MessageType.call;

    const radius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    // "end" is the sender side: right in LTR, left in RTL, like WhatsApp.
    final borderRadius = BorderRadiusDirectional.only(
      topStart: radius,
      topEnd: radius,
      bottomStart: !mine && tail ? tailRadius : radius,
      bottomEnd: mine && tail ? tailRadius : radius,
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: borderRadius),
        child: Padding(
          padding: isImage
              ? const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 6)
              : const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null)
                Padding(
                  padding: isImage || isVoice
                      ? const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 4)
                      : const EdgeInsets.only(bottom: 2),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      senderName!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: senderColor(message.senderId ?? '', theme.brightness),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (isImage) ChatImage(message: message),
              if (isVoice) VoiceMessageView(message: message, foreground: foreground),
              if (isCall) CallMessageView(message: message, mine: mine, foreground: foreground),
              if (text.isNotEmpty)
                Padding(
                  padding: isImage ? const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 0) : EdgeInsets.zero,
                  child: Text(
                    text,
                    textDirection: textDirectionOf(text),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: deleted ? metaColor : foreground,
                      fontStyle: deleted ? FontStyle.italic : null,
                      height: 1.35,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Padding(
                padding: isImage ? const EdgeInsetsDirectional.only(end: 6) : EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messageTime(context, message.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(color: metaColor),
                    ),
                    if (mine && !isCall) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(
                        status: message.sendStatus,
                        receipt: receipt,
                        color: metaColor,
                        errorColor: scheme.error,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Full row width, so the bubble sits on its sender's side instead of being centered by the list item.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: tail ? 8 : 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: onRetry, child: bubble),
          if (message.sendStatus == SendStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.notSentTapToRetry, style: theme.textTheme.labelSmall?.copyWith(color: scheme.error)),
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.receipt, required this.color, required this.errorColor});

  static const _readColor = Color(0xFF34B7F1);

  final SendStatus status;
  final ReceiptStatus receipt;
  final Color color;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    return switch ((status, receipt)) {
      (SendStatus.sending, _) => Icon(Icons.schedule_rounded, size: 14, color: color),
      (SendStatus.failed, _) => Icon(Icons.error_outline_rounded, size: 16, color: errorColor),
      (_, ReceiptStatus.sent) => Icon(Icons.check_rounded, size: 16, color: color),
      (_, ReceiptStatus.delivered) => Icon(Icons.done_all_rounded, size: 16, color: color),
      (_, ReceiptStatus.read) => const Icon(Icons.done_all_rounded, size: 16, color: _readColor),
    };
  }
}

const _senderPalette = [
  Color(0xFFE53935),
  Color(0xFF8E24AA),
  Color(0xFF3949AB),
  Color(0xFF039BE5),
  Color(0xFF00897B),
  Color(0xFF7CB342),
  Color(0xFFF4511E),
  Color(0xFFD81B60),
];

/// Stable per-user name colour in groups, lightened for dark mode.
Color senderColor(String userId, Brightness brightness) {
  final hash = userId.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  final base = _senderPalette[hash % _senderPalette.length];
  return brightness == Brightness.dark ? Color.lerp(base, Colors.white, 0.35)! : base;
}
