import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "npm:stripe@14.0.0"; // Deno supports npm: prefix
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ENV } from "./.envs.ts";
// Webhook secret from Stripe Dashboard
function mapStripeInvoiceStatus(eventType, invoiceStatus) {
  switch(eventType){
    case "invoice.created":
      return "upcoming";
    case "invoice.finalized":
      return "processing";
    case "invoice.payment_succeeded":
      return "collected";
    case "invoice.paid":
      return "collected";
    case "invoice.payment_failed":
    case "invoice.marked_uncollectible":
      return "failed";
    case "invoice.voided":
      return "failed"; // you might want "canceled" if you add that later
    case "invoice.updated":
      // fall back to actual invoice.status if needed
      switch(invoiceStatus){
        case "draft":
          return "upcoming";
        case "open":
          return "processing";
        case "paid":
          return "collected";
        case "uncollectible":
          return "failed";
        case "void":
          return "failed";
      }
      break;
    default:
      return "processing"; // safe fallback
  }
}
serve(async (req) => {
  // Stripe + Supabase setup
  let stripe, event;
  const supabase = createClient(ENV.SUPABASE_URL, ENV.SUPABASE_SERVICE_ROLE_KEY);
  const signature = req.headers.get("stripe-signature");
  const body = await req.text();
  try {
    stripe = new Stripe(ENV.STRIPE_API_KEY, {
      apiVersion: "2024-06-20",
    });
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      ENV.STRIPE_INVOICE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("⚠️  Webhook signature verification failed:", err.message);
    return new Response(`Webhook Error: ${err.message}`, {
      status: 400,
    });
  }
  if (event.type.startsWith("invoice.")) {
    const invoice = event.data.object;
    const { data, error } = await supabase.from("invoices").update({
      amount: invoice.amount_paid / 100,
      status: invoice.status,
      hosted_invoice_url: invoice.hosted_invoice_url,
      invoice_pdf: invoice.invoice_pdf,
      stripe_customer_id: invoice.customer,
      stripe_created_at: new Date(invoice.created * 1000).toISOString()
    }).eq("stripe_invoice_id", invoice.id).select("id");
    if (error) {
      console.error("❌ Failed to update invoice:", error);
      return new Response("DB Error", {
        status: 500
      });
    }
    const dbStatus = mapStripeInvoiceStatus(event.type, invoice.status);
    await supabase.from("payments").update({
      status: dbStatus
    }).filter("invoice_id", "eq", data[0]?.id).select();
    await supabase.from("wip_one_time_payments").update({
      status: dbStatus
    }).eq("invoice_id", data[0]?.id);
    console.log(`✅ Synced invoice ${invoice.id} (${invoice.status}) (${dbStatus})`);
  }
  return new Response(JSON.stringify({
    received: true
  }), {
    status: 200
  });
});
