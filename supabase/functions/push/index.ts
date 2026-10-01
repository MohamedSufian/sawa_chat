// Sawa Chat — push notifications.
//
// Called by Database Webhooks:
//   messages INSERT        → a notification per recipient device, in its language
//   calls INSERT / UPDATE  → a data-only "incoming call" push that wakes the app
//                            (CallKit UI), and a "call_end" push to dismiss it.
//
// Secrets (Supabase Dashboard → Edge Functions → Secrets):
//   FCM_SERVICE_ACCOUNT  the Firebase service-account JSON, pasted whole
//   WEBHOOK_SECRET       random string; the webhook sends it in `x-webhook-secret`
// SUPABASE_URL and the service key are provided by the platform.

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type MessageRow = {
  id: string;
  chat_id: string;
  sender_id: string | null;
  type: "text" | "image" | "voice" | "system" | "call";
  content: string | null;
  deleted_for_everyone: boolean;
};

type Locale = "ar" | "en";

const STRINGS: Record<Locale, { photo: string; voice: string; message: string }> = {
  en: { photo: "📷 Photo", voice: "🎤 Voice message", message: "New message" },
  ar: { photo: "📷 صورة", voice: "🎤 رسالة صوتية", message: "رسالة جديدة" },
};

const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  // Projects on the new API keys expose them as JSON instead.
  JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}").default;

const db = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey, {
  auth: { persistSession: false },
});

const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
const webhookSecret = Deno.env.get("WEBHOOK_SECRET");

// ---- Google OAuth (service account → short-lived access token) ------------

let cachedToken: { value: string; expiresAt: number } | null = null;

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const key = await importPKCS8(serviceAccount.private_key, "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new Error(`Google OAuth failed: ${res.status} ${await res.text()}`);

  const json = await res.json();
  cachedToken = { value: json.access_token, expiresAt: now + json.expires_in };
  return cachedToken.value;
}

// ---- FCM -------------------------------------------------------------------

/** Returns false when the token is dead and should be deleted. */
async function sendToDevice(token: string, title: string, body: string, chatId: string): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${await googleAccessToken()}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: { kind: "message", chat_id: chatId },
          android: {
            priority: "HIGH",
            // One notification per chat, replaced by the newest message.
            notification: { channel_id: "messages", tag: chatId, sound: "default" },
          },
          apns: { payload: { aps: { sound: "default", "thread-id": chatId } } },
        },
      }),
    },
  );
  if (res.ok) return true;

  const error = await res.text();
  console.error(`FCM ${res.status}: ${error}`);
  return !(res.status === 404 || error.includes("UNREGISTERED"));
}

function preview(message: MessageRow, locale: Locale): string {
  const s = STRINGS[locale];
  if (message.type === "image") return s.photo;
  if (message.type === "voice") return s.voice;
  const text = (message.content ?? "").replace(/\s+/g, " ").trim();
  return text.length > 120 ? `${text.slice(0, 117)}…` : text || s.message;
}

async function notifyNewMessage(message: MessageRow) {
  // Group events and deleted messages don't ring phones.
  if (message.type === "system" || message.type === "call" || message.deleted_for_everyone) return;
  if (!message.sender_id) return;

  const [{ data: chat }, { data: sender }, { data: members }] = await Promise.all([
    db.from("chats").select("id, type, name").eq("id", message.chat_id).single(),
    db.from("profiles").select("display_name").eq("id", message.sender_id).single(),
    db.from("chat_members").select("user_id").eq("chat_id", message.chat_id)
      .neq("user_id", message.sender_id).eq("muted", false),
  ]);
  if (!chat || !sender || !members?.length) return;

  const { data: devices } = await db.from("device_tokens")
    .select("token, locale")
    .in("user_id", members.map((m) => m.user_id));
  if (!devices?.length) return;

  const deadTokens: string[] = [];
  await Promise.all(devices.map(async (device) => {
    const locale: Locale = device.locale?.startsWith("ar") ? "ar" : "en";
    const text = preview(message, locale);
    const isGroup = chat.type === "group";
    const title = isGroup ? chat.name : sender.display_name;
    const body = isGroup ? `${sender.display_name}: ${text}` : text;
    if (!(await sendToDevice(device.token, title, body, chat.id))) deadTokens.push(device.token);
  }));

  if (deadTokens.length) await db.from("device_tokens").delete().in("token", deadTokens);
}

type CallRow = {
  id: string;
  caller_id: string;
  callee_id: string;
  kind: "audio" | "video";
  status: string;
};

/** Data-only, high priority: the app's background handler draws the call UI itself. */
async function sendData(token: string, data: Record<string, string>, ttlSeconds: number): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${await googleAccessToken()}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: { token, data, android: { priority: "HIGH", ttl: `${ttlSeconds}s` } },
      }),
    },
  );
  if (res.ok) return true;
  const error = await res.text();
  console.error(`FCM ${res.status}: ${error}`);
  return !(res.status === 404 || error.includes("UNREGISTERED"));
}

async function notifyCall(call: CallRow, oldStatus: string | undefined) {
  const { data: devices } = await db.from("device_tokens").select("token").eq("user_id", call.callee_id);
  if (!devices?.length) return;

  let data: Record<string, string>;
  if (call.status === "ringing" && oldStatus === undefined) {
    const { data: caller } = await db.from("profiles").select("display_name, avatar_url")
      .eq("id", call.caller_id).single();
    data = {
      kind: "call",
      call_id: call.id,
      caller_id: call.caller_id,
      caller_name: caller?.display_name ?? "",
      caller_avatar: caller?.avatar_url ?? "",
      video: call.kind === "video" ? "1" : "0",
    };
  } else if (oldStatus === "ringing" && call.status !== "ringing") {
    // Answered, declined, cancelled or timed out: stop ringing on the callee's phone.
    data = { kind: "call_end", call_id: call.id, status: call.status };
  } else {
    return;
  }

  // A ring that arrives late is worse than none.
  const ttl = data.kind === "call" ? 30 : 60;
  const dead: string[] = [];
  await Promise.all(devices.map(async (d) => {
    if (!(await sendData(d.token, data, ttl))) dead.push(d.token);
  }));
  if (dead.length) await db.from("device_tokens").delete().in("token", dead);
}

Deno.serve(async (req) => {
  if (!webhookSecret || req.headers.get("x-webhook-secret") !== webhookSecret) {
    return new Response("forbidden", { status: 403 });
  }

  const payload = await req.json();
  try {
    if (payload.type === "INSERT" && payload.table === "messages") {
      await notifyNewMessage(payload.record as MessageRow);
    }
    if (payload.table === "calls" && (payload.type === "INSERT" || payload.type === "UPDATE")) {
      await notifyCall(payload.record as CallRow, payload.old_record?.status);
    }
    return new Response("ok");
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
