import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/routes.dart';
import '../../profile/domain/profile.dart';
import '../data/call_repository.dart';
import '../domain/call.dart';

enum CallPhase { idle, outgoing, incoming, connecting, connected, ended }

enum CallEndReason { ended, declined, busy, noAnswer, cancelled, failed }

class CallSessionState {
  const CallSessionState({
    this.phase = CallPhase.idle,
    this.call,
    this.peer,
    this.video = false,
    this.muted = false,
    this.speakerOn = false,
    this.cameraOff = false,
    this.connectedAt,
    this.endReason,
  });

  final CallPhase phase;
  final CallRecord? call;
  final Profile? peer;
  final bool video;
  final bool muted;
  final bool speakerOn;
  final bool cameraOff;
  final DateTime? connectedAt;
  final CallEndReason? endReason;

  bool get active => phase != CallPhase.idle && phase != CallPhase.ended;

  CallSessionState copyWith({
    CallPhase? phase,
    CallRecord? call,
    bool? muted,
    bool? speakerOn,
    bool? cameraOff,
    DateTime? connectedAt,
    CallEndReason? endReason,
  }) => CallSessionState(
    phase: phase ?? this.phase,
    call: call ?? this.call,
    peer: peer,
    video: video,
    muted: muted ?? this.muted,
    speakerOn: speakerOn ?? this.speakerOn,
    cameraOff: cameraOff ?? this.cameraOff,
    connectedAt: connectedAt ?? this.connectedAt,
    endReason: endReason ?? this.endReason,
  );
}

/// The one call this device can be in. Owns the WebRTC peer connection, the
/// media, the signaling channel and the call row subscription.
///
/// Signaling (Realtime Broadcast on `call:<id>`):
///   callee joins → "ready" (repeated until an offer arrives)
///   caller → "offer", callee → "answer", both ↔ "ice", either → "hangup"
final callSessionProvider = NotifierProvider<CallSessionController, CallSessionState>(CallSessionController.new);

class CallSessionController extends Notifier<CallSessionState> {
  static const _ringTimeout = Duration(seconds: 45);

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RealtimeChannel? _signal;
  RealtimeChannel? _row;
  Timer? _timeout;
  Timer? _readyRetry;
  final _pendingIce = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  bool _offerSent = false;

  CallRepository get _repo => ref.read(callRepositoryProvider);

  @override
  CallSessionState build() {
    ref.onDispose(() {
      _teardown();
      localRenderer.dispose();
      remoteRenderer.dispose();
    });
    return const CallSessionState();
  }

  // ---- Entry points -----------------------------------------------------------

  Future<void> startOutgoing(Profile peer, {required bool video}) async {
    if (state.active) return;
    _reset();
    state = CallSessionState(phase: CallPhase.outgoing, peer: peer, video: video, speakerOn: video);
    _openCallScreen();

    try {
      await _prepareMedia(video: video);
      final call = await _repo.start(peer.id, video: video);
      if (!state.active) return; // Hung up while we were setting up.
      state = state.copyWith(call: call);

      if (call.status == CallStatus.busy) return _finish(CallEndReason.busy);
      _watchRow(call.id);
      _joinSignaling(call.id, asCaller: true);
      _timeout = Timer(_ringTimeout, () {
        if (state.phase == CallPhase.outgoing) _end(CallStatus.missed, CallEndReason.noAnswer);
      });
    } catch (e) {
      debugPrint('Starting call failed: $e');
      _finish(CallEndReason.failed);
    }
  }

  /// A ringing call for me, seen while the app is open (or opened from CallKit).
  Future<void> showIncoming(CallRecord call, Profile peer, {bool acceptNow = false}) async {
    if (state.active) {
      if (state.call?.id == call.id) {
        // Same call already ringing in-app, now accepted from the native call UI.
        if (acceptNow) await accept();
      } else {
        // Already on another call.
        unawaited(_repo.setStatus(call.id, CallStatus.declined));
      }
      return;
    }
    _reset();
    state = CallSessionState(
      phase: CallPhase.incoming,
      call: call,
      peer: peer,
      video: call.isVideo,
      speakerOn: call.isVideo,
    );
    _watchRow(call.id);
    _openCallScreen();
    if (acceptNow) await accept();
  }

  Future<void> accept() async {
    final call = state.call;
    if (call == null || state.phase != CallPhase.incoming) return;
    state = state.copyWith(phase: CallPhase.connecting);
    unawaited(FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id: call.id)));

    try {
      await _prepareMedia(video: state.video);
      await _repo.setStatus(call.id, CallStatus.accepted);
      _joinSignaling(call.id, asCaller: false);
    } catch (e) {
      debugPrint('Accepting call failed: $e');
      _end(CallStatus.ended, CallEndReason.failed);
    }
  }

  Future<void> decline() => _end(CallStatus.declined, CallEndReason.declined);

  Future<void> hangUp() => switch (state.phase) {
    CallPhase.outgoing => _end(CallStatus.cancelled, CallEndReason.cancelled),
    CallPhase.incoming => _end(CallStatus.declined, CallEndReason.declined),
    _ => _end(CallStatus.ended, CallEndReason.ended),
  };

  // ---- Controls -----------------------------------------------------------------

  void toggleMute() {
    final muted = !state.muted;
    for (final t in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    state = state.copyWith(muted: muted);
  }

  Future<void> toggleSpeaker() async {
    final on = !state.speakerOn;
    await Helper.setSpeakerphoneOn(on);
    state = state.copyWith(speakerOn: on);
  }

  void toggleCamera() {
    final off = !state.cameraOff;
    for (final t in _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !off;
    }
    state = state.copyWith(cameraOff: off);
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  // ---- Media & WebRTC -------------------------------------------------------------

  Future<void> _prepareMedia({required bool video}) async {
    if (!_renderersReady) {
      await Future.wait([localRenderer.initialize(), remoteRenderer.initialize()]);
      _renderersReady = true;
    }
    _localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24} : false,
    });
    localRenderer.srcObject = _localStream;
    await Helper.setSpeakerphoneOn(video);
  }

  Future<RTCPeerConnection> _createPeer() async {
    final pc = await createPeerConnection({'iceServers': Env.iceServers, 'sdpSemantics': 'unified-plan'});
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _send({'type': 'ice', 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) remoteRenderer.srcObject = event.streams.first;
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          if (state.phase != CallPhase.connected) {
            state = state.copyWith(phase: CallPhase.connected, connectedAt: DateTime.now());
            if (state.call case final call?) FlutterCallkitIncoming.setCallConnected(call.id);
          }
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _end(CallStatus.ended, CallEndReason.failed);
        default:
          break;
      }
    };
    return pc;
  }

  void _joinSignaling(String callId, {required bool asCaller}) {
    _signal = _repo.signaling(
      callId,
      onSignal: _onSignal,
      onJoined: () {
        if (asCaller) return;
        // Tell the caller we're here; repeat in case the first one is missed.
        _send({'type': 'ready'});
        _readyRetry = Timer.periodic(const Duration(seconds: 2), (t) {
          if (_remoteDescriptionSet || t.tick > 8) return t.cancel();
          _send({'type': 'ready'});
        });
      },
    );
  }

  Future<void> _onSignal(Map<String, dynamic> signal) async {
    try {
      switch (signal['type']) {
        case 'ready' when !_offerSent:
          _offerSent = true;
          state = state.copyWith(phase: CallPhase.connecting);
          _pc = await _createPeer();
          final offer = await _pc!.createOffer();
          await _pc!.setLocalDescription(offer);
          _send({'type': 'offer', 'sdp': offer.sdp});

        case 'offer' when _pc == null:
          _readyRetry?.cancel();
          _pc = await _createPeer();
          await _setRemote(RTCSessionDescription(signal['sdp'] as String, 'offer'));
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          _send({'type': 'answer', 'sdp': answer.sdp});

        case 'answer' when !_remoteDescriptionSet:
          await _setRemote(RTCSessionDescription(signal['sdp'] as String, 'answer'));

        case 'ice':
          final candidate = RTCIceCandidate(
            signal['candidate'] as String,
            signal['sdpMid'] as String?,
            (signal['sdpMLineIndex'] as num?)?.toInt(),
          );
          // Candidates can arrive before the description they belong to.
          if (_pc == null || !_remoteDescriptionSet) {
            _pendingIce.add(candidate);
          } else {
            await _pc!.addCandidate(candidate);
          }

        case 'hangup':
          _finish(CallEndReason.ended);
      }
    } catch (e) {
      debugPrint('Signaling error: $e');
      _end(CallStatus.ended, CallEndReason.failed);
    }
  }

  Future<void> _setRemote(RTCSessionDescription description) async {
    await _pc!.setRemoteDescription(description);
    _remoteDescriptionSet = true;
    for (final c in _pendingIce) {
      await _pc!.addCandidate(c);
    }
    _pendingIce.clear();
  }

  void _send(Map<String, dynamic> signal) {
    if (_signal case final channel?) _repo.sendSignal(channel, signal).ignore();
  }

  /// The other side declining, cancelling or timing out shows up on the call row.
  void _watchRow(String callId) {
    _row = _repo.watch(callId, (call) {
      if (!state.active) return;
      final reason = switch (call.status) {
        CallStatus.declined => CallEndReason.declined,
        CallStatus.busy => CallEndReason.busy,
        CallStatus.missed => CallEndReason.noAnswer,
        CallStatus.cancelled => CallEndReason.cancelled,
        CallStatus.ended => CallEndReason.ended,
        _ => null,
      };
      if (reason != null) _finish(reason);
    });
  }

  // ---- Ending ------------------------------------------------------------------------

  Future<void> _end(CallStatus status, CallEndReason reason) async {
    if (!state.active) return;
    final call = state.call;
    _send({'type': 'hangup'});
    _finish(reason);
    if (call != null) {
      try {
        await _repo.setStatus(call.id, status);
      } catch (e) {
        debugPrint('Updating call status failed: $e');
      }
    }
  }

  void _finish(CallEndReason reason) {
    if (state.phase == CallPhase.ended || state.phase == CallPhase.idle) return;
    final callId = state.call?.id;
    _teardown();
    if (callId != null) unawaited(FlutterCallkitIncoming.endCall(callId));
    state = state.copyWith(phase: CallPhase.ended, endReason: reason);

    // Leave the "Call ended" screen up briefly, then go idle (the screen pops).
    Timer(const Duration(milliseconds: 1500), () {
      if (ref.mounted && state.phase == CallPhase.ended) state = const CallSessionState();
    });
  }

  void _teardown() {
    _timeout?.cancel();
    _readyRetry?.cancel();
    if (_signal case final channel?) _repo.unsubscribe(channel);
    if (_row case final channel?) _repo.unsubscribe(channel);
    _signal = null;
    _row = null;
    _pc?.close();
    _pc = null;
    for (final t in _localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      t.stop();
    }
    _localStream?.dispose();
    _localStream = null;
    if (_renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    Helper.setSpeakerphoneOn(false).ignore();
  }

  void _reset() {
    _pendingIce.clear();
    _remoteDescriptionSet = false;
    _offerSent = false;
  }

  void _openCallScreen() => ref.read(routerProvider).push(Routes.call);
}
