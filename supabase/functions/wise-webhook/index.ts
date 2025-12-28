import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getEnv } from "./.envs.ts";
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
serve(async (req)=>{
  const ENV = getEnv();
  const supabase = createClient(ENV.SUPABASE_URL, ENV.SUPABASE_SERVICE_ROLE_KEY);
  const rawBody = await req.text();
  const payload = JSON.parse(rawBody);
  // Handle payment request events
  if (payload.eventType === "payment_request.status_changed" || payload.eventType === "payment_request.updated") {
    const paymentRequest = payload.data;
    const paymentRequestId = paymentRequest.id;
    const status = paymentRequest.status;
    // paymentRequestId from webhook is the wise_invoice_id or payment_request_id
    // Step 1: Find the row in wise_invoices table where wise_invoice_id or payment_request_id = paymentRequestId
    // Try wise_invoice_id first, then payment_request_id
    let { data: wiseInvoiceData, error: wiseInvoiceError } = await supabase.from("wise_invoices").select("invoice_id, id, wise_invoice_id, payment_request_id").eq("wise_invoice_id", paymentRequestId).single();
    // If not found by wise_invoice_id, try payment_request_id
    if (wiseInvoiceError || !wiseInvoiceData) {
      const { data, error } = await supabase.from("wise_invoices").select("invoice_id, id, wise_invoice_id, payment_request_id").eq("payment_request_id", paymentRequestId).single();
      wiseInvoiceData = data;
      wiseInvoiceError = error;
    }
    if (wiseInvoiceError || !wiseInvoiceData) {
      console.error("❌ Failed to find wise invoice:", wiseInvoiceError);
      console.log(`Invoice ${paymentRequestId} (wise_invoice_id/payment_request_id) not found in wise_invoices table`);
      return new Response("Invoice not found", {
        status: 404
      });
    }
    // Step 2: Get the invoice_id from the wise_invoices row
    const invoiceId = wiseInvoiceData.invoice_id;
    console.log(`Found invoice: wise_invoice_id/payment_request_id=${paymentRequestId}, invoice_id=${invoiceId}`);
    // Step 3: Normalize the status
    const normalizedStatus = normalizeInvoiceStatus(status);
    // Step 4: Update the invoices table where id = invoice_id
    const { data: invoiceData, error: invoiceError } = await supabase.from("invoices").update({
      status: normalizedStatus,
      invoice_link: paymentRequest.link || paymentRequest.publicUrl || null
    }).eq("id", invoiceId).select("id");
    if (invoiceError) {
      console.error("❌ Failed to update invoice:", invoiceError);
      return new Response("DB Error", {
        status: 500
      });
    }
    // Update wise_invoices table with latest data
    // Update by the ID we found
    const { error: wiseUpdateError } = await supabase.from("wise_invoices").update({
      raw_payload: paymentRequest
    }).eq("id", wiseInvoiceData.id);
    if (wiseUpdateError) {
      console.error("❌ Failed to update wise_invoices:", wiseUpdateError);
    // Don't fail the whole request, just log the error
    }
    // Update payments and one-time payments with normalized status
    // Note: Using "processing" for non-paid statuses, "paid" for paid statuses
    await supabase.from("payments").update({
      status: normalizedStatus === "paid" ? "paid" : "processing"
    }).eq("invoice_id", invoiceId);
    await supabase.from("wip_one_time_payments").update({
      status: normalizedStatus === "paid" ? "paid" : "processing"
    }).eq("invoice_id", invoiceId);
    console.log(`✅ Synced invoice ${paymentRequestId} (Wise: ${status}, Normalized: ${normalizedStatus})`);
  }
  return new Response(JSON.stringify({
    received: true
  }), {
    status: 200
  });
});
