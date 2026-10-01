import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/providers/core_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/router/routes.dart';
import '../auth/application/session_controller.dart';
import '../calls/application/incoming_call_listener.dart';

/// Firebase bootstrap. Push is optional: without `google-services.json` /
/// `GoogleService-Info.plist` the app runs normally with push disabled.
abstract final class PushSetup {
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      available = true;
    } catch (e) {
      debugPrint('Push notifications disabled: $e');
    }
  }
}

/// Runs in a background isolate when a push arrives while the app isn't in the
/// foreground: rings for calls, and otherwise marks messages delivered (✓✓),
/// since reaching the device is exactly what "delivered" means.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  switch (message.data['kind']) {
    case 'call':
      return showNativeIncomingCall(message.data);
    case 'call_end':
      if (message.data['call_id'] case final String callId) await FlutterCallkitIncoming.endCall(callId);
      return;
  }

  if (!Env.isConfigured) return;
  try {
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = (await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey)).client;
    }
    if (client.auth.currentSession != null) await client.rpc<void>('mark_all_delivered');
  } catch (e) {
    debugPrint('Background delivery mark failed: $e');
  }
}

/// The chat currently on screen; its messages don't need a notification.
final activeChatProvider = NotifierProvider<ActiveChatController, String?>(ActiveChatController.new);

class ActiveChatController extends Notifier<String?> {
  @override
  String? build() => null;

  void enter(String chatId) => state = chatId;

  void leave(String chatId) {
    if (state == chatId) state = null;
  }
}

/// Registers this device for push while someone is signed in, shows
/// notifications in the foreground, and opens the right chat when one is tapped.
final pushProvider = NotifierProvider<PushController, void>(PushController.new);

class PushController extends Notifier<void> {
  static const _channel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();

  SupabaseClient get _client => ref.read(supabaseProvider);

  @override
  void build() {
    final myId = ref.watch(sessionControllerProvider.select((s) => s.profile?.id));
    if (myId == null || !PushSetup.available) return;

    // Notification text is rendered server-side in this language.
    final locale = ref.watch(localeProvider)?.languageCode ?? PlatformDispatcher.instance.locale.languageCode;

    final subs = <StreamSubscription<dynamic>>[];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
    });
    ref.listen(activeChatProvider, (_, chatId) {
      if (chatId != null) _clearChatNotifications(chatId);
    });

    _setup(myId, locale, subs);
  }

  Future<void> _setup(String myId, String locale, List<StreamSubscription<dynamic>> subs) async {
    final messaging = FirebaseMessaging.instance;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final chatId?) _openChat(chatId);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final permission = await messaging.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied || !ref.mounted) return;

    try {
      final token = await messaging.getToken();
      if (token != null) await _register(token, myId, locale);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
    if (!ref.mounted) return;

    subs
      ..add(messaging.onTokenRefresh.listen((t) => _register(t, myId, locale)))
      ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened));

    // The app was launched by tapping a notification.
    final initial = await messaging.getInitialMessage();
    if (initial != null && ref.mounted) _onOpened(initial);
  }

  Future<void> _register(String token, String myId, String locale) => _client.from('device_tokens').upsert({
    'token': token,
    'user_id': myId,
    'platform': Platform.isIOS ? 'ios' : 'android',
    'locale': locale,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  /// Call before signing out so this device stops receiving the account's messages.
  Future<void> unregister() async {
    if (!PushSetup.available) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _client.from('device_tokens').delete().eq('token', token);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM unregister failed: $e');
    }
  }

  /// Android doesn't show FCM notifications while the app is open, so we do,
  /// unless the user is already looking at that chat.
  void _onForegroundMessage(RemoteMessage message) {
    // Calls are handled over Realtime while the app is open; just make sure a
    // native ring started in the background stops when the call does.
    if (message.data['kind'] == 'call_end') {
      if (message.data['call_id'] case final String callId) FlutterCallkitIncoming.endCall(callId);
      return;
    }
    final chatId = message.data['chat_id'] as String?;
    final notification = message.notification;
    if (chatId == null || notification == null || chatId == ref.read(activeChatProvider)) return;

    _local.show(
      id: chatId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: chatId,
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'messages'),
      ),
      payload: chatId,
    );
  }

  void _onOpened(RemoteMessage message) {
    if (message.data['chat_id'] case final String chatId) _openChat(chatId);
  }

  void _openChat(String chatId) {
    final router = ref.read(routerProvider);
    router.go(Routes.chats);
    router.push(Routes.chat(chatId));
  }

  /// Removes this chat's notifications from the tray once it's opened. FCM posts
  /// them with id 0 and the chat id as tag; ours use the chat id's hash.
  void _clearChatNotifications(String chatId) {
    _local.cancel(id: 0, tag: chatId);
    _local.cancel(id: chatId.hashCode, tag: chatId);
  }
}
