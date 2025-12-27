import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "npm:stripe@14.0.0"; // Deno supports npm: prefix
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getEnv } from "./.envs.ts";

/**
 * Normalizes invoice status to either "paid" or "processing"
 * @param status - The raw status from Stripe
 * @returns Normalized status: "paid" or "processing"
 */
function normalizeInvoiceStatus(status) {
  if (!status) {
    return "processing";
  }

  const normalizedStatus = status.toLowerCase();

  // Stripe invoice statuses: draft, open, paid, uncollectible, void
  // Only "paid" maps to "paid", everything else is "processing"
  return normalizedStatus === "paid" ? "paid" : "processing";
}
serve(async (req) => {
  const ENV = getEnv();
  // Stripe + Supabase setup
  let stripe, event;
  const supabase = createClient(
    ENV.SUPABASE_URL,
    ENV.SUPABASE_SERVICE_ROLE_KEY
  );
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
    console.error(
      "⚠️  PROD Webhook signature verification failed:",
      err.message
    );
    try {
      stripe = new Stripe(ENV.STRIPE_API_KEY_TEST, {
        apiVersion: "2024-06-20",
      });
      event = await stripe.webhooks.constructEventAsync(
        body,
        signature,
        ENV.STRIPE_INVOICE_WEBHOOK_SECRET_TEST
      );
    } catch (err) {
      console.error(
        "⚠️  TEST Webhook signature verification failed:",
        err.message
      );
      return new Response(`Webhook Error: ${err.message}`, {
        status: 400,
      });
    }
  }
  if (event.type.startsWith("invoice.")) {
    const invoice = event.data.object;
    // invoice.id from webhook is the stripe_invoice_id

    // Step 1: Find the row in stripe_invoices table where stripe_invoice_id = invoice.id (from webhook)
    const { data: stripeInvoiceData, error: stripeInvoiceError } =
      await supabase
        .from("stripe_invoices")
        .select("invoice_id, id")
        .eq("stripe_invoice_id", invoice.id)
        .single();

    if (stripeInvoiceError || !stripeInvoiceData) {
      console.error("❌ Failed to find stripe invoice:", stripeInvoiceError);
      console.log(
        `Invoice ${invoice.id} (stripe_invoice_id) not found in stripe_invoices table`
      );
      return new Response("Invoice not found", {
        status: 404,
      });
    }

    // Step 2: Get the invoice_id from the stripe_invoices row
    const invoiceId = stripeInvoiceData.invoice_id;
    console.log(
      `Found invoice: stripe_invoice_id=${invoice.id}, invoice_id=${invoiceId}`
    );

    // Step 3: Normalize the status
    const normalizedStatus = normalizeInvoiceStatus(invoice.status);

    // Step 4: Update the invoices table where id = invoice_id
    const { data: invoiceData, error: invoiceError } = await supabase
      .from("invoices")
      .update({
        status: normalizedStatus,
        invoice_link: invoice.hosted_invoice_url || null,
      })
      .eq("id", invoiceId)
      .select("id");

    if (invoiceError) {
      console.error("❌ Failed to update invoice:", invoiceError);
      return new Response("DB Error", {
        status: 500,
      });
    }

    // Update stripe_invoices table with latest data
    const { error: stripeUpdateError } = await supabase
      .from("stripe_invoices")
      .update({
        stripe_customer_id: invoice.customer,
        stripe_created_at: new Date(invoice.created * 1000).toISOString(),
        raw_payload: invoice,
      })
      .eq("stripe_invoice_id", invoice.id);

    if (stripeUpdateError) {
      console.error("❌ Failed to update stripe_invoices:", stripeUpdateError);
      // Don't fail the whole request, just log the error
    }

    // Update payments and one-time payments with normalized status
    // Note: Using "processing" for non-paid statuses, "paid" for paid statuses
    await supabase
      .from("payments")
      .update({
        status: normalizedStatus === "paid" ? "paid" : "processing",
      })
      .eq("invoice_id", invoiceId);

    await supabase
      .from("wip_one_time_payments")
      .update({
        status: normalizedStatus === "paid" ? "paid" : "processing",
      })
      .eq("invoice_id", invoiceId);

    console.log(
      `✅ Synced invoice ${invoice.id} (Stripe: ${invoice.status}, Normalized: ${normalizedStatus})`
    );
  }
  return new Response(
    JSON.stringify({
      received: true,
    }),
    {
      status: 200,
    }
  );
});
