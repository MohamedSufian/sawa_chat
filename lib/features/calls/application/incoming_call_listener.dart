import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../data/call_repository.dart';
import '../domain/call.dart';
import 'call_session_controller.dart';

/// Shows the native incoming-call UI from a push while the app is in the
/// background or killed (called from the FCM background handler).
Future<void> showNativeIncomingCall(Map<String, dynamic> data) async {
  final callId = data['call_id'] as String?;
  if (callId == null) return;
  final video = data['video'] == '1';
  final name = (data['caller_name'] as String?) ?? '';
  final avatar = data['caller_avatar'] as String?;

  await FlutterCallkitIncoming.showCallkitIncoming(
    CallKitParams(
      id: callId,
      nameCaller: name,
      appName: 'Sawa',
      avatar: (avatar?.isEmpty ?? true) ? null : avatar,
      handle: video ? 'Video call' : 'Voice call',
      type: video ? 1 : 0,
      duration: 45000,
      extra: <String, dynamic>{'call_id': callId, 'caller_id': data['caller_id']},
      missedCallNotification: const NotificationParams(showNotification: true, isShowCallback: false),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0E9F8E',
        actionColor: '#22C55E',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        isShowFullLockedScreen: true,
      ),
      ios: const IOSParams(handleType: 'generic', supportsVideo: true),
    ),
  );
}

/// While signed in: rings for incoming calls (Realtime when the app is open)
/// and reacts to the native call UI (accept / decline).
final incomingCallListenerProvider = Provider<void>((ref) {
  final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
  if (myId == null) return;

  final repo = ref.read(callRepositoryProvider);
  final session = ref.read(callSessionProvider.notifier);

  Future<void> present(CallRecord call, {bool acceptNow = false}) async {
    // Stale rings (e.g. a push that arrived late) are ignored.
    if (call.status != CallStatus.ringing || DateTime.now().difference(call.createdAt).inSeconds > 60) {
      unawaited(FlutterCallkitIncoming.endCall(call.id));
      return;
    }
    final caller = await ref.read(profileRepositoryProvider).fetch(call.callerId);
    if (caller != null) await session.showIncoming(call, caller, acceptNow: acceptNow);
  }

  final channel = repo.watchIncoming(present);

  final events = FlutterCallkitIncoming.onEvent.listen((event) async {
    try {
      switch (event) {
        case CallEventActionCallAccept(:final callKitParams):
          final call = await repo.fetch(callKitParams.id);
          if (call != null) await present(call, acceptNow: true);
        case CallEventActionCallDecline(:final callKitParams):
          await repo.setStatus(callKitParams.id, CallStatus.declined);
        default:
          break;
      }
    } catch (e) {
      debugPrint('CallKit event failed: $e');
    }
  });

  // Cold start from the native call UI: the accept tap happened before we listened.
  Future<void>(() async {
    try {
      for (final params in await FlutterCallkitIncoming.activeCalls()) {
        final call = await repo.fetch(params.id);
        if (call != null) await present(call, acceptNow: params.isAccepted);
      }
    } catch (e) {
      debugPrint('Checking active calls failed: $e');
    }
  });

  ref.onDispose(() {
    events.cancel();
    repo.unsubscribe(channel);
  });
});
