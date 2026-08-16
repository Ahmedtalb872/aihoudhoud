// Sends a data-only FCM push to every eligible online captain when a new
// trip request appears, so NewTripAlert can ring/full-screen them even if
// the app is backgrounded or fully killed - in-app Supabase Realtime (see
// AppStateProvider._subscribeToPendingRides) only fires while some Dart
// code from the app is actually running, which doesn't cover "app closed".
//
// Called directly from Postgres by the trg_notify_new_trip_request trigger
// (migration 0017) via pg_net, not by the Flutter client - protected by a
// shared secret header instead of a user JWT since there's no user session
// involved in a database trigger calling out.
//
// Required secrets (see supabase/functions/README or deploy notes):
//   TRIP_PUSH_TRIGGER_SECRET     shared secret the DB trigger also sends
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

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Cached in module scope so a warm Edge Function instance reuses the same
// access token across invocations instead of round-tripping to Google's
// token endpoint on every single push.
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

async function sendPush(
  deviceToken: string,
  projectId: string,
  data: Record<string, string>,
) {
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
          data,
          android: { priority: "high" },
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

    const { trip_id } = await req.json();
    if (!trip_id) return json({ error: "missing_trip_id" }, 400);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);

    const { data: trip, error: tripError } = await supabase
      .from("trips")
      .select(
        "id, service_type, pickup_address, customer_id, recipient_name",
      )
      .eq("id", trip_id)
      .maybeSingle();
    if (tripError || !trip) return json({ error: "trip_not_found" }, 404);

    let customerName = "زبون جديد";
    if (trip.service_type === "delivery" && trip.recipient_name) {
      customerName = trip.recipient_name;
    } else if (trip.customer_id) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", trip.customer_id)
        .maybeSingle();
      if (profile?.full_name) customerName = profile.full_name;
    }

    // Mirrors AppStateProvider._maybeShowNextPendingRide's eligibility
    // rules: a motorcycle captain only ever wakes for delivery requests
    // (and only once opted in); a car captain wakes for regular rides
    // always, deliveries too once opted in.
    let query = supabase
      .from("captains")
      .select("fcm_token")
      .eq("status", "approved")
      .eq("is_online", true)
      .not("fcm_token", "is", null);
    if (trip.service_type === "delivery") {
      query = query.eq("accepts_delivery", true);
    } else {
      query = query.neq("vehicle_type", "motorcycle");
    }
    const { data: captains, error: captainsError } = await query;
    if (captainsError) return json({ error: captainsError.message }, 500);

    const pushData = {
      type: "new_trip",
      tripId: String(trip.id),
      customerName,
      pickup: trip.pickup_address ?? "",
    };

    const results = await Promise.allSettled(
      (captains ?? [])
        .filter((c) => !!c.fcm_token)
        .map((c) => sendPush(c.fcm_token as string, serviceAccount.project_id, pushData)),
    );

    return json({ sent: results.length });
  } catch (_e) {
    return json({ error: "internal_error" }, 500);
  }
});
