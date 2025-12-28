// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { DatabaseService } from "./database-service.ts";
import { ENV } from "./.envs.ts";
// CORS headers consistent with other functions
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
async function handler(req) {
  // Handle preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  const contentType = req.headers.get("content-type") || "";
  let parsed = undefined;
  if (contentType.includes("multipart/form-data")) {
    // parse as form-data
    const formData = await req.formData();
    const fields = {};
    for (const [key, value] of formData.entries()){
      fields[key] = value;
    }
    // HelloSign sends actual JSON inside a "json" field
    if (typeof fields.json === "string") {
      try {
        parsed = JSON.parse(fields.json);
      } catch  {
        console.warn("Failed to parse HelloSign json field");
        parsed = {};
      }
    } else {
      parsed = fields;
    }
  } else if (contentType.includes("application/json")) {
    try {
      parsed = await req.json();
    } catch  {
      parsed = {};
    }
  } else {
    // fallback for debugging
    const rawBody = await req.text();
    console.log("Raw body:", rawBody);
    parsed = {};
  }
  // Only handle signature_request_all_signed events; ignore others
  const eventType = parsed?.event?.event_type;
  if (eventType !== "signature_request_all_signed" && eventType !== "signature_request_signed") {
    return new Response("Hello API Event Received and ignored", {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const reqData = parsed?.signature_request ?? {};
  const requestId = reqData?.signature_request_id ?? reqData?.signature_request?.signature_request_id;
  const title = reqData?.title ?? reqData?.original_title ?? "";
  const subject = reqData?.subject ?? "";
  const filesUrl = reqData?.files_url ?? reqData?.files?.url ?? "";
  const signatures = Array.isArray(reqData?.signatures) ? reqData.signatures : [];
  const signerSummaries = signatures.map((s)=>({
      signer_name: s?.signer_name ?? s?.name ?? "",
      signer_email: s?.signer_email_address ?? s?.email_address ?? "",
      status: s?.status_code ?? s?.status ?? "",
      signed_at: s?.signed_at ?? null,
      order: s?.order ?? null
    }));
  // const allSigned = signerSummaries.length > 0 && signerSummaries.every((s)=>(s.status ?? '').toLowerCase() === 'signed');
  // console.log("allSigned:", allSigned);
  // console.log(allSigned);
  // if (allSigned) {
  const databaseService = new DatabaseService(ENV.SUPABASE_URL, ENV.SUPABASE_KEY);
  await databaseService.updateHelloSignDocumentStatus(requestId, "signed");
  // }
  console.log("HelloSign signature", {
    requestId,
    title,
    subject,
    filesUrl,
    signerCount: signerSummaries.length,
    signerSummaries
  });
  // Ack
  return new Response('Hello API Event Received and accepted', {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
serve(handler);
export default serve;
