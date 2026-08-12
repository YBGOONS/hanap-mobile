// PayMongo calls this directly (not a Supabase-authenticated client), so
// verify_jwt is off for this function (see supabase/config.toml) and trust
// is instead established via PAYMONGO_WEBHOOK_SECRET signature checking.
// Uses the service-role key since there's no user JWT to run RLS as.
import { createClient } from "npm:@supabase/supabase-js@2";

const PAYMONGO_SECRET_KEY = Deno.env.get("PAYMONGO_SECRET_KEY")!;
const PAYMONGO_WEBHOOK_SECRET = Deno.env.get("PAYMONGO_WEBHOOK_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// PAYMONGO_WEBHOOK_SECRET is only known once the webhook is registered in
// the PayMongo dashboard (chicken-and-egg — the endpoint has to exist
// first). Until it's set, requests are allowed through unverified so the
// endpoint is usable immediately after deploy; set the secret and this
// starts enforcing automatically, no redeploy needed.
async function verifySignature(rawBody: string, signatureHeader: string | null): Promise<boolean> {
  if (!PAYMONGO_WEBHOOK_SECRET) return true;
  if (!signatureHeader) return false;

  const parts = Object.fromEntries(signatureHeader.split(",").map((p) => p.split("=")));
  const timestamp = parts["t"];
  const testSig = parts["te"];
  if (!timestamp || !testSig) return false;

  const signedPayload = `${timestamp}.${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(PAYMONGO_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuffer = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signedPayload));
  const computed = Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return computed === testSig;
}

// Charges the now-chargeable source and, on success, mirrors exactly what
// the old mark_job_paid RPC used to do (escrow the payment, generate the
// arrival OTP, log the transaction with its 90/10 split, notify both
// parties) — just triggered by PayMongo instead of a direct client call.
async function payAndRelease(sourceId: string) {
  const { data: job } = await supabase
    .from("jobs")
    .select("*")
    .eq("paymongo_source_id", sourceId)
    .eq("payment_status", "unpaid")
    .maybeSingle();

  if (!job) return; // already processed, or unknown source — idempotent no-op

  const budget = Number(job.budget ?? 0);
  const fee = Math.round(budget * 0.1 * 100) / 100;
  const totalCentavos = Math.round((budget + fee) * 100);

  const paymentRes = await fetch("https://api.paymongo.com/v1/payments", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Basic " + btoa(`${PAYMONGO_SECRET_KEY}:`),
    },
    body: JSON.stringify({
      data: {
        attributes: {
          amount: totalCentavos,
          currency: "PHP",
          source: { id: sourceId, type: "source" },
        },
      },
    }),
  });
  const paymentData = await paymentRes.json();
  const status = paymentData?.data?.attributes?.status;
  if (!paymentRes.ok || status !== "paid") return;

  const otp = String(Math.floor(1000 + Math.random() * 9000));

  await supabase
    .from("jobs")
    .update({ payment_status: "paid", service_fee: fee, arrival_otp: otp })
    .eq("id", job.id);

  await supabase.from("transactions").insert({
    job_id: job.id,
    client_id: job.client_id,
    worker_id: job.worker_id,
    amount: budget + fee,
    worker_amount: budget,
    platform_fee: fee,
    type: "payment",
  });

  await supabase.from("notifications").insert([
    {
      user_id: job.worker_id,
      title: "Client paid for the job",
      body: `The client paid for your "${job.category}" job and is escrowed with HANAP. Ask them for the arrival code when you get there.`,
      job_id: job.id,
    },
    {
      user_id: job.client_id,
      title: "Payment held in escrow",
      body: `Share this code with your worker when they arrive: ${otp}`,
      job_id: job.id,
    },
  ]);
}

Deno.serve(async (req) => {
  const rawBody = await req.text();
  const signature = req.headers.get("Paymongo-Signature");

  const valid = await verifySignature(rawBody, signature);
  if (!valid) {
    return new Response("Invalid signature", { status: 401 });
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const type = (event?.data as any)?.attributes?.type;

  try {
    if (type === "source.chargeable") {
      const sourceId = (event.data as any).attributes.data.id;
      await payAndRelease(sourceId);
    }
  } catch (e) {
    console.error("Webhook handling error:", e);
  }

  return new Response("ok", { status: 200 });
});
