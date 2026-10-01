import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/media_repository.dart';
import '../../domain/message.dart';

/// Image content of a message: local bytes while sending, signed URL once stored.
/// Space is reserved from the stored width/height so the list never jumps.
class ChatImage extends StatelessWidget {
  const ChatImage({super.key, required this.message, this.maxWidth = 260});

  final Message message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ratio = (message.aspectRatio ?? 1).clamp(0.6, 1.8);
    final progress = message.uploadProgress;
    final sending = message.sendStatus == SendStatus.sending;

    return GestureDetector(
      onTap: message.sendStatus == SendStatus.failed ? null : () => ImageViewerScreen.open(context, message),
      child: SizedBox(
        width: maxWidth,
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: _heroTag(message),
                  child: MessageImageSource(message: message),
                ),
                if (sending && progress != null && progress < 1) _UploadProgress(progress: progress),
                if (message.sendStatus == SendStatus.failed)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: Icon(Icons.refresh_rounded, color: Colors.white, size: 36)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _heroTag(Message m) => 'chat-image-${m.clientId}';

/// Picks the right source for a message image; shared by the bubble and the viewer.
class MessageImageSource extends ConsumerWidget {
  const MessageImageSource({super.key, required this.message, this.fit = BoxFit.cover});

  final Message message;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(color: scheme.surfaceContainerHighest);

    final bytes = message.localBytes;
    if (bytes != null) return Image.memory(bytes, fit: fit, gaplessPlayback: true);

    final path = message.mediaPath;
    if (path == null) return placeholder;

    final url = ref.watch(mediaUrlProvider(path));
    return switch (url) {
      AsyncData(:final value) => CachedNetworkImage(
        imageUrl: value,
        // Signed URLs change every hour; cache by the stable storage path instead.
        cacheKey: path,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
        ),
      ),
      AsyncError() => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
      ),
      _ => placeholder,
    };
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x55000000),
      child: Center(
        child: SizedBox.square(
          dimension: 52,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
              Center(
                child: Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.message});

  final Message message;

  static void open(BuildContext context, Message message) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => ImageViewerScreen(message: message),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, leading: const CloseButton()),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: AspectRatio(
            aspectRatio: message.aspectRatio ?? 1,
            child: Hero(
              tag: _heroTag(message),
              child: MessageImageSource(message: message, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
