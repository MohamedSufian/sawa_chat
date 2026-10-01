import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../domain/voice.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    this.onPickImages,
    this.onVoiceRecorded,
    this.onTyping,
    this.onStopTyping,
  });

  final ValueChanged<String> onSend;

  /// Receives local file paths of the picked images.
  final ValueChanged<List<String>>? onPickImages;
  final ValueChanged<VoiceRecording>? onVoiceRecorded;
  final VoidCallback? onTyping;
  final VoidCallback? onStopTyping;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  static const _maxImagesPerPick = 10;
  static const _minVoiceLength = Duration(seconds: 1);
  static const _maxVoiceLength = Duration(minutes: 5);

  /// How far (px) the finger must slide toward the start edge to cancel.
  static const _cancelDistance = 110.0;

  final _controller = TextEditingController();
  final _recorder = AudioRecorder();

  bool _pressing = false;
  bool _recording = false;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  double _slide = 0;
  final _samples = <double>[];
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    if (_recording) _recorder.cancel();
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---- Text ------------------------------------------------------------------

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  // ---- Images ----------------------------------------------------------------

  Future<void> _pickImages() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.pickFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final files = source == ImageSource.gallery
        ? await picker.pickMultiImage(limit: _maxImagesPerPick)
        : [?await picker.pickImage(source: ImageSource.camera)];
    if (files.isNotEmpty) widget.onPickImages?.call([for (final f in files) f.path]);
  }

  // ---- Voice -----------------------------------------------------------------

  Future<void> _startRecording() async {
    final l10n = context.l10n;
    if (!await _recorder.hasPermission()) {
      if (mounted) showErrorSnack(context, l10n.micPermission);
      return;
    }
    // The permission dialog may have swallowed the press; don't record a stray clip.
    if (!_pressing || !mounted) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 44100, numChannels: 1),
      path: path,
    );
    if (!_pressing || !mounted) {
      await _recorder.cancel();
      return;
    }

    HapticFeedback.mediumImpact();
    _samples.clear();
    _startedAt = DateTime.now();
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
      _slide = 0;
    });
    widget.onStopTyping?.call();

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((a) => _samples.add(normalizeDbfs(a.current)));
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      if (_elapsed >= _maxVoiceLength) _finishRecording(send: true);
    });
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _ticker?.cancel();
    await _amplitudeSub?.cancel();
    final elapsed = DateTime.now().difference(_startedAt!);
    setState(() => _recording = false);

    if (!send || elapsed < _minVoiceLength) {
      await _recorder.cancel(); // Also deletes the file.
      if (send && mounted) showErrorSnack(context, context.l10n.holdToRecord);
      return;
    }

    final path = await _recorder.stop();
    if (path == null) return;
    widget.onVoiceRecorded?.call(VoiceRecording(path: path, duration: elapsed, waveform: downsampleWaveform(_samples)));
  }

  void _onSlide(LongPressMoveUpdateDetails details, bool rtl) {
    if (!_recording) return;
    // "Toward the start" is left in LTR and right in RTL.
    final towardStart = rtl ? details.offsetFromOrigin.dx : -details.offsetFromOrigin.dx;
    setState(() => _slide = math.max(0, towardStart));
    if (_slide > _cancelDistance) {
      HapticFeedback.lightImpact();
      _finishRecording(send: false);
    }
  }

  // ---- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 8),
        child: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            final showMic = !hasText && widget.onVoiceRecorded != null;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onPickImages != null && !_recording)
                  IconButton(
                    tooltip: l10n.attachPhoto,
                    onPressed: _pickImages,
                    icon: Icon(Icons.add_photo_alternate_outlined, color: scheme.primary),
                  ),
                Expanded(child: _recording ? _buildRecordingBar(context) : _buildTextField(context, value.text)),
                const SizedBox(width: 8),
                if (showMic) _buildMicButton(context) else _buildSendButton(context, hasText),
              ],
            );
          },
        ),
      ),
    );
  }

  InputBorder get _pillBorder =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none);

  Widget _buildTextField(BuildContext context, String text) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 6,
      maxLength: 4000,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      // Follow the language being typed, not just the UI language.
      textDirection: text.trim().isNotEmpty ? textDirectionOf(text) : null,
      onChanged: (t) => t.trim().isEmpty ? widget.onStopTyping?.call() : widget.onTyping?.call(),
      decoration: InputDecoration(
        hintText: context.l10n.typeMessage,
        counterText: '',
        border: _pillBorder,
        enabledBorder: _pillBorder,
        focusedBorder: _pillBorder,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }

  Widget _buildRecordingBar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blinkOn = _elapsed.inMilliseconds ~/ 500 % 2 == 0;
    final cancelProgress = (_slide / _cancelDistance).clamp(0.0, 1.0);

    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: blinkOn ? 1 : 0.2,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.mic_rounded, color: scheme.error, size: 22),
          ),
          const SizedBox(width: 8),
          Text(
            formatVoiceDuration(_elapsed),
            textDirection: TextDirection.ltr,
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          // The hint follows the finger toward the start edge and fades as it nears cancel.
          Transform.translate(
            offset: Offset((Directionality.of(context) == TextDirection.rtl ? 1 : -1) * _slide * 0.6, 0),
            child: Opacity(
              opacity: 1 - cancelProgress * 0.7,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mirrors in RTL, so it always points toward the start edge.
                  Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
                  Text(context.l10n.slideToCancel, style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Semantics(
      button: true,
      label: context.l10n.recordVoice,
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            // Much shorter than the default 500 ms so recording feels instant.
            () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 150)),
            (recognizer) => recognizer
              ..onLongPressDown = (_) {}
              ..onLongPressStart = (_) {
                _pressing = true;
                _startRecording();
              }
              ..onLongPressMoveUpdate = (d) {
                _onSlide(d, rtl);
              }
              ..onLongPressEnd = (_) {
                _pressing = false;
                _finishRecording(send: true);
              }
              // Released before the hold registered: it was a tap, explain the gesture.
              ..onLongPressCancel = () {
                showErrorSnack(context, context.l10n.holdToRecord);
              },
          ),
        },
        child: AnimatedScale(
          scale: _recording ? 1.25 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _recording ? scheme.error : scheme.primary, shape: BoxShape.circle),
            child: Icon(Icons.mic_rounded, color: _recording ? scheme.onError : scheme.onPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, bool hasText) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: context.l10n.send,
      onPressed: hasText ? _submit : null,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      // Icons.send_rounded is mirrored automatically in RTL.
      icon: const Icon(Icons.send_rounded),
    );
  }
}
