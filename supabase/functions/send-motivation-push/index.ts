// Sends the daily morning/evening motivational push to every approved
// captain via FCM - a server-side replacement for the old client-side
// flutter_local_notifications schedule (MotivationNotifications, now
// removed from the Flutter app).
//
// That local approach silently never fired for a lot of captains: Android
// clears AlarmManager-scheduled notifications on a device reboot (no boot
// receiver was wired up to reschedule them) and, more commonly on the
// budget/OEM-heavy Android phones this app's captains actually use
// (Xiaomi/Redmi, Vivo, Oppo, Tecno, Infinix...), aggressive battery
// managers force-stop backgrounded apps outright, which cancels every
// pending alarm until the captain happens to reopen the app - with no
// error, log, or any way for us to know it silently stopped working.
//
// A server-triggered FCM push has none of those failure modes: it doesn't
// depend on the app being open, not force-stopped, or the device not
// having rebooted - only on Play Services being alive, which every other
// push in this app (new-trip alerts) already relies on and is proven to
// work. Uses FCM's `notification` payload (not the trip-push function's
// data-only one) so Android/Play Services displays it directly with zero
// app code needing to run at all.
//
// Triggered by two pg_cron jobs (migration 0027) at 08:00 and 19:00 UTC -
// Mauritania is UTC+0 year-round, so no timezone conversion is needed.
//
// Required secrets (already set for send-trip-push, reused here):
//   TRIP_PUSH_TRIGGER_SECRET       shared secret the cron job also sends
//   FIREBASE_SERVICE_ACCOUNT_JSON  the full service-account key JSON, as one string
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://esm.sh/jose@5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TRIGGER_SECRET = Deno.env.get("TRIP_PUSH_TRIGGER_SECRET") ?? "";
const FIREBASE_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-internal-secret",
};

// Same wording MotivationNotifications used client-side - one is picked at
// random per push so captains don't see the exact same line every day.
const MORNING_MESSAGES = [
  "صباح الخير يا كابتن الهدهد! يوم جديد مليء بالفرص، نتمنى لك رحلة آمنة ومباركة.",
  "صباح النشاط! كل مشوار اليوم خطوة نحو هدفك - بالتوفيق يا كابتن.",
  "صباح الخير! ابدأ يومك بثقة، الطريق أمامك مفتوح والرزق بيد الله.",
  "يوم جديد، فرصة جديدة. نتمنى لك صباحًا هادئًا ومشاوير موفقة.",
  "صباح الخير يا شريك الهدهد! جهدك اليوم لا يضيع، بالتوفيق.",
];

const EVENING_MESSAGES = [
  "مساء الخير يا كابتن الهدهد! شكرًا لجهدك اليوم، نتمنى لك أمسية هادئة وراحة مستحقة.",
  "مساء الخير! يوم آخر أنجزته بجد - فخورين بك شريك الهدهد.",
  "مساء الخير يا كابتن، إلى الراحة الآن، وغدًا يوم جديد بإذن الله.",
  "شكرًا على تعبك اليوم يا كابتن الهدهد، مساءً طيبًا لك ولعائلتك.",
  "مساء الخير! كل مشوار قدّمته اليوم كان فرقًا لأحدهم - بالتوفيق دائمًا.",
];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getFcmAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
  const privateKey = await jose.importPKCS8(serviceAccount.private_key, "RS256");
  const jwt = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuedAt()
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setExpirationTime("1h")
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data?.access_token) throw new Error("fcm_auth_failed");
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return cachedAccessToken.token;
}

async function sendPush(deviceToken: string, projectId: string, title: string, body: string) {
  const accessToken = await getFcmAccessToken();
  return fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          // Targets the app's own "general_notifications" Android channel
          // (created client-side in NewTripAlert._createGeneralChannel) so
          // this plays that channel's own tone instead of the device's
          // generic default notification sound - without a channel_id here,
          // Play Services displays it on Android's bare default channel.
          android: {
            priority: "normal",
            notification: {
              channel_id: "general_notifications",
              sound: "general_notification",
            },
          },
        },
      }),
    },
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (TRIGGER_SECRET && req.headers.get("x-internal-secret") !== TRIGGER_SECRET) {
      return json({ error: "unauthorized" }, 401);
    }
    if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
      return json({ error: "firebase_not_configured" }, 500);
    }

    const { period } = await req.json();
    const isMorning = period === "morning";
    if (!isMorning && period !== "evening") {
      return json({ error: "invalid_period" }, 400);
    }

    const messages = isMorning ? MORNING_MESSAGES : EVENING_MESSAGES;
    const title = isMorning ? "صباح الخير يا كابتن" : "مساء الخير يا كابتن";
    const body = messages[Math.floor(Math.random() * messages.length)];

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);

    const { data: captains, error } = await supabase
      .from("captains")
      .select("id, fcm_token")
      .eq("status", "approved")
      .not("fcm_token", "is", null);
    if (error) return json({ error: error.message }, 500);

    const results = await Promise.allSettled(
      (captains ?? [])
        .filter((c) => !!c.fcm_token)
        .map((c) => sendPush(c.fcm_token as string, serviceAccount.project_id, title, body)),
    );

    return json({ sent: results.length, period });
  } catch (_e) {
    return json({ error: "internal_error" }, 500);
  }
});
