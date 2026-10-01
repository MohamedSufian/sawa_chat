# Push notifications setup

Push is optional: without these steps the app runs normally, just without notifications.

```
message INSERT ──► Database Webhook ──► Edge Function `push` ──► FCM ──► device
                     (x-webhook-secret)    (service account)
```

## 1. Firebase (free Spark plan)

1. [console.firebase.google.com](https://console.firebase.google.com) → **Create a project** (Google Analytics not needed).
2. **Add app → Android**, package name `com.sawa.sawa_chat`.
3. Download `google-services.json` into `android/app/` (it's git-ignored).
4. **Project settings → Service accounts → Generate new private key**. Keep this JSON private; never commit it.

iOS additionally needs `ios/Runner/GoogleService-Info.plist`, the Push Notifications capability in Xcode, and an APNs key, which requires a paid Apple Developer account.

## 2. Edge Function

Supabase Dashboard → **Edge Functions**:

1. **Secrets**: add
   - `FCM_SERVICE_ACCOUNT` = the whole service-account JSON from step 1.4
   - `WEBHOOK_SECRET` = a long random string
2. **Deploy a new function → Via editor**, name it `push`, paste `supabase/functions/push/index.ts`, deploy.
3. In the function's settings, turn **Verify JWT** off. The function checks `x-webhook-secret` instead.

Or with the CLI: `supabase functions deploy push --no-verify-jwt`.

## 3. Database Webhook

Supabase Dashboard → **Database → Webhooks → Create a new hook**:

- Table `messages`, event **Insert**
- Type **Supabase Edge Functions**, function `push`, method POST
- HTTP header `x-webhook-secret` = the same value as `WEBHOOK_SECRET`

Create a **second** hook the same way for calls: table `calls`, events **Insert** and **Update**.
It rings the callee's phone (native call screen) even when the app is closed, and stops the ring when the caller hangs up.

## 4. Test

Run the app on a real device (or an emulator image with Google Play), sign in, then send a message from another account while the app is in the background. Logs: Dashboard → Edge Functions → `push` → Logs.
