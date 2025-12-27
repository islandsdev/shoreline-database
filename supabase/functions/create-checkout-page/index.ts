import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";
import { getEnv } from "./.envs.ts";
// ---------- Shared ----------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    },
    status
  });
}
function handleOptions(req) {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  return null;
}
// ---------- Stripe Utilities ----------
function createStripeClient(IS_TEST_ENV) {
  const ENV = getEnv(IS_TEST_ENV);
  return new Stripe(ENV.STRIPE_API_KEY, {
    apiVersion: "2025-07-30.basil"
  });
}
async function createCheckoutSession({ stripe, mode = "subscription", priceId, customerId, employeeCount = 1, coupon, metadata, origin }) {
  const baseSession = {
    customer: customerId,
    mode,
    payment_method_types: [
      "card"
    ],
    payment_method_collection: "if_required",
    line_items: [
      {
        price: priceId,
        quantity: employeeCount
      }
    ],
    success_url: `${origin}/plan?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/plan`,
    metadata
  };
  const discountConfig = coupon ? {
    discounts: [
      {
        promotion_code: coupon
      }
    ]
  } : {
    allow_promotion_codes: true
  };
  if (mode === "subscription") {
    baseSession.subscription_data = {
      metadata
    };
  }
  return await stripe.checkout.sessions.create({
    ...baseSession,
    ...discountConfig
  });
}
// ---------- Request Handler ----------
async function handleCreateCheckout(req) {
  const { priceId, customerId, userId, companyId, employeeCount = 1, coupon, IS_TEST_ENV, mode = "subscription", metadata = {} } = await req.json();
  if (!priceId || !customerId || !userId || !companyId) {
    return jsonResponse({
      error: "Missing required parameters"
    }, 400);
  }
  const stripe = createStripeClient(IS_TEST_ENV);
  const origin = req.headers.get("origin") ?? "https://localhost:8080";
  // ✅ Metadata is passed directly from frontend — no reconstruction needed
  const session = await createCheckoutSession({
    stripe,
    mode,
    priceId,
    customerId,
    employeeCount,
    coupon,
    metadata,
    origin
  });
  return jsonResponse({
    url: session.url
  });
}
// ---------- Server Entrypoint ----------
serve(async (req)=>{
  const preflight = handleOptions(req);
  if (preflight) return preflight;
  try {
    return await handleCreateCheckout(req);
  } catch (e) {
    console.error("❌ Checkout Error:", e);
    const message = e instanceof Error ? e.message : "Unknown error";
    return jsonResponse({
      error: message
    }, 400);
  }
});
