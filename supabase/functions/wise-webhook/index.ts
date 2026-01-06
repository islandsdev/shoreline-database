import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ENV } from "./.envs.ts";
/**
 * Normalizes invoice status to either "paid" or "processing"
 * @param status - The raw status from Wise
 * @returns Normalized status: "paid" or "processing"
 */ function normalizeInvoiceStatus(status) {
  if (!status) {
    return "processing";
  }
  const normalizedStatus = status.toLowerCase();
  // Wise invoice statuses: PUBLISHED, PAID, etc.
  // Only "paid" maps to "paid", everything else is "processing"
  return normalizedStatus === "paid" ? "paid" : "processing";
}

async function findCandidateInvoices(
  supabase,
  amount,
  timeWindowStart,
  timeWindowEnd
) {
  // Query from invoices and join to wise_invoices for better filtering and ordering
  const { data, error } = await supabase
    .from("invoices")
    .select(
      `
      id,
      amount,
      status,
      created_at,
      provider,
      wise_invoices!inner (
        id,
        wise_invoice_id,
        payment_request_id,
        profile_id
      )
    `
    )
    .eq("provider", "Wise")
    .eq("status", "processing")
    .eq("amount", amount)
    .gte("created_at", timeWindowStart.toISOString())
    .lte("created_at", timeWindowEnd.toISOString())
    .order("created_at", { ascending: false });
  if (error) {
    console.error("❌ Error finding candidate invoices:", error);
    return [];
  }
  // Transform the data to match expected structure
  return (
    data?.map((item) => ({
      id: item.id,
      amount: item.amount,
      status: item.status,
      created_at: item.created_at,
      wise_invoices: item.wise_invoices || [],
    })) || []
  );
}

async function verifyInvoiceViaWiseAPI(paymentRequestId) {
  try {
    const profileId = ENV.WISE_PROFILE_ID;
    if (!profileId) {
      console.error("❌ WISE_PROFILE_ID not configured");
      return false;
    }
    const response = await fetch(
      `https://wise.com/gateway/v2/profiles/${profileId}/acquiring/payment-requests/${paymentRequestId}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${ENV.WISE_API_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );
    if (!response.ok) {
      console.error(
        `❌ Wise API error: ${response.status} ${response.statusText}`
      );
      return false;
    }
    const paymentRequest = await response.json();
    console.log(">>>>>>>>:", paymentRequest);
    return paymentRequest.status === "COMPLETED";
  } catch (error) {
    console.error("❌ Error verifying invoice via Wise API:", error);
    return false;
  }
}
/**
 * Updates invoice and related records to paid status
 * @param supabase - Supabase client
 * @param invoiceId - Invoice ID to update
 */
async function updateInvoiceToPaid(supabase, invoiceId) {
  // Check if already paid (idempotency)
  const { data: currentInvoice } = await supabase
    .from("invoices")
    .select("status")
    .eq("id", invoiceId)
    .single();
  if (currentInvoice && currentInvoice.status === "paid") {
    console.log(
      `ℹ️ Invoice ${invoiceId} already marked as paid, skipping update`
    );
    return;
  }
  // Update invoice status
  const { error: invoiceError } = await supabase
    .from("invoices")
    .update({
      status: "paid",
    })
    .eq("id", invoiceId);
  if (invoiceError) {
    console.error("❌ Failed to update invoice:", invoiceError);
    throw invoiceError;
  }
  // Update payments
  await supabase
    .from("payments")
    .update({
      status: "paid",
    })
    .eq("invoice_id", invoiceId);
  // Update one-time payments
  await supabase
    .from("wip_one_time_payments")
    .update({
      status: "paid",
    })
    .eq("invoice_id", invoiceId);
  console.log(
    `✅ Updated invoice ${invoiceId} and related records to paid status`
  );
}
/**
 * Handles balance credit webhook events
 * @param supabase - Supabase client
 * @param webhookData - Balance credit webhook data
 */
async function handleBalanceCreditEvent(supabase, webhookData) {
  const { amount, currency, occurred_at, resource } = webhookData.data;
  console.log("💰 Processing balance credit webhook:", {
    amount,
    currency,
    occurred_at,
  });
  // Calculate time window (±2 hours from payment time)
  const paymentTime = new Date(occurred_at);
  const timeWindowStart = new Date(paymentTime.getTime() - 2 * 60 * 60 * 1000);
  const timeWindowEnd = new Date(paymentTime.getTime() + 2 * 60 * 60 * 1000);
  // Find candidate invoices
  const candidates = await findCandidateInvoices(
    supabase,
    amount,
    timeWindowStart,
    timeWindowEnd
  );
  console.log(`🔍 Found ${candidates.length} candidate invoice(s)`);
  if (candidates.length === 0) {
    console.warn(
      `⚠️ No candidate invoices found for amount ${amount}, time window ${timeWindowStart.toISOString()} to ${timeWindowEnd.toISOString()}`
    );
    return;
  }
  // Process each candidate until we find a paid one
  for (const candidate of candidates) {
    const wiseInvoice = candidate.wise_invoices[0];
    if (!wiseInvoice || !wiseInvoice.payment_request_id) {
      console.warn(
        `⚠️ Candidate invoice ${candidate.id} missing payment_request_id, skipping`
      );
      continue;
    }
    console.log(
      `🔎 Verifying invoice ${candidate.id} (payment_request_id: ${wiseInvoice.payment_request_id})`
    );
    const isPaid = await verifyInvoiceViaWiseAPI(
      wiseInvoice.payment_request_id
    );
    if (isPaid) {
      console.log(
        `✅ Verified invoice ${candidate.id} is paid via Wise API, updating status`
      );
      await updateInvoiceToPaid(supabase, candidate.id);
      return; // Found and updated, stop processing
    } else {
      console.log(
        `ℹ️ Invoice ${candidate.id} not confirmed as paid via Wise API, checking next candidate`
      );
    }
  }
  console.warn(
    `⚠️ No invoices verified as paid among ${candidates.length} candidate(s)`
  );
}
serve(async (req) => {
  const supabase = createClient(
    ENV.SUPABASE_URL,
    ENV.SUPABASE_SERVICE_ROLE_KEY
  );
  const rawBody = await req.text();
  const payload = JSON.parse(rawBody);
  // Handle balance credit events (no payment request ID provided)
  const eventType = payload.event_type || payload.eventType;
  if (eventType === "balances#credit") {
    console.log("💰 Received balances#credit webhook");
    try {
      await handleBalanceCreditEvent(supabase, payload);
    } catch (error) {
      console.error("❌ Error handling balance credit event:", error);
      // Don't fail the webhook, just log the error
    }
  }
  // Handle payment request events
  if (
    payload.eventType === "payment_request.status_changed" ||
    payload.eventType === "payment_request.updated"
  ) {
    const paymentRequest = payload.data;
    const paymentRequestId = paymentRequest.id;
    const status = paymentRequest.status;
    // paymentRequestId from webhook is the wise_invoice_id or payment_request_id
    // Step 1: Find the row in wise_invoices table where wise_invoice_id or payment_request_id = paymentRequestId
    // Try wise_invoice_id first, then payment_request_id
    let { data: wiseInvoiceData, error: wiseInvoiceError } = await supabase
      .from("wise_invoices")
      .select("invoice_id, id, wise_invoice_id, payment_request_id")
      .eq("wise_invoice_id", paymentRequestId)
      .single();
    // If not found by wise_invoice_id, try payment_request_id
    if (wiseInvoiceError || !wiseInvoiceData) {
      const { data, error } = await supabase
        .from("wise_invoices")
        .select("invoice_id, id, wise_invoice_id, payment_request_id")
        .eq("payment_request_id", paymentRequestId)
        .single();
      wiseInvoiceData = data;
      wiseInvoiceError = error;
    }
    if (wiseInvoiceError || !wiseInvoiceData) {
      console.error("❌ Failed to find wise invoice:", wiseInvoiceError);
      console.log(
        `Invoice ${paymentRequestId} (wise_invoice_id/payment_request_id) not found in wise_invoices table`
      );
      return new Response("Invoice not found", {
        status: 404,
      });
    }
    // Step 2: Get the invoice_id from the wise_invoices row
    const invoiceId = wiseInvoiceData.invoice_id;
    console.log(
      `Found invoice: wise_invoice_id/payment_request_id=${paymentRequestId}, invoice_id=${invoiceId}`
    );
    // Step 3: Normalize the status
    const normalizedStatus = normalizeInvoiceStatus(status);
    // Step 4: Update the invoices table where id = invoice_id
    const { data: invoiceData, error: invoiceError } = await supabase
      .from("invoices")
      .update({
        status: normalizedStatus,
        invoice_link: paymentRequest.link || paymentRequest.publicUrl || null,
      })
      .eq("id", invoiceId)
      .select("id");
    if (invoiceError) {
      console.error("❌ Failed to update invoice:", invoiceError);
      return new Response("DB Error", {
        status: 500,
      });
    }
    // Update wise_invoices table with latest data
    // Update by the ID we found
    const { error: wiseUpdateError } = await supabase
      .from("wise_invoices")
      .update({
        raw_payload: paymentRequest,
      })
      .eq("id", wiseInvoiceData.id);
    if (wiseUpdateError) {
      console.error("❌ Failed to update wise_invoices:", wiseUpdateError);
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
      `✅ Synced invoice ${paymentRequestId} (Wise: ${status}, Normalized: ${normalizedStatus})`
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
