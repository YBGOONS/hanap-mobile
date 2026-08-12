// Client calls this instead of the old mark_job_paid RPC once PayMongo is
// wired up — it does the same eligibility check (own job, accepted,
// unpaid) but creates a real GCash checkout session instead of instantly
// flipping payment_status. The RPC itself stays in schema.sql unused by
// the client now; the actual "mark paid" write happens in
// paymongo-webhook once PayMongo confirms the charge.
import { createClient } from "npm:@supabase/supabase-js@2";

const PAYMONGO_SECRET_KEY = Deno.env.get("PAYMONGO_SECRET_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// jobs_client_updates_own_open_job (schema.sql) only allows a client to
// update their OWN job while status = 'open' — an accepted job (which is
// exactly when payment happens) is outside that policy, so saving
// paymongo_source_id back onto the job needs the service role to bypass
// RLS. Ownership/eligibility is already verified above with the user's
// own JWT before this ever runs.
const adminSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { job_id } = await req.json();
    if (!job_id) {
      return new Response(JSON.stringify({ error: "job_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: job, error: jobError } = await supabase
      .from("jobs")
      .select("id, client_id, category, budget, status, payment_status")
      .eq("id", job_id)
      .eq("client_id", user.id)
      .eq("status", "accepted")
      .eq("payment_status", "unpaid")
      .single();

    if (jobError || !job) {
      return new Response(JSON.stringify({ error: "Job is not eligible for payment right now." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const budget = Number(job.budget ?? 0);
    const fee = Math.round(budget * 0.1 * 100) / 100;
    const totalCentavos = Math.round((budget + fee) * 100);

    const origin = req.headers.get("origin") ?? SUPABASE_URL;
    const paymongoRes = await fetch("https://api.paymongo.com/v1/sources", {
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
            type: "gcash",
            redirect: {
              success: `${origin}/#/payment-success?job_id=${job.id}`,
              failed: `${origin}/#/payment-failed?job_id=${job.id}`,
            },
          },
        },
      }),
    });

    const paymongoData = await paymongoRes.json();
    if (!paymongoRes.ok) {
      return new Response(
        JSON.stringify({ error: paymongoData?.errors?.[0]?.detail ?? "PayMongo request failed." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const sourceId = paymongoData.data.id;
    const checkoutUrl = paymongoData.data.attributes.redirect.checkout_url;

    const { error: updateError } = await adminSupabase.from("jobs").update({ paymongo_source_id: sourceId }).eq("id", job.id);
    if (updateError) {
      return new Response(JSON.stringify({ error: `Could not link the payment to the job: ${updateError.message}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ checkout_url: checkoutUrl }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
