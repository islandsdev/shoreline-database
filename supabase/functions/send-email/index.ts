// deno-lint-ignore-file no-explicit-any
/* eslint-disable @typescript-eslint/no-explicit-any */ import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { sendEmail } from "./_resend-send-mail.ts";
import { EmailAction, actionTemplates } from "./_email-templates.ts";
import { RESEND_API_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "./envs.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// Define base schema
const BaseActionSchema = z.object({
  action: z.nativeEnum(EmailAction)
});
const WelcomeActionSchema = BaseActionSchema.extend({
  action: z.literal(EmailAction.WELCOME),
  user_id: z.string()
});
const handler = async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const supabase = createClient(SUPABASE_URL ?? "", SUPABASE_SERVICE_ROLE_KEY ?? "");
    const rawRequest = await req.json();
    const validation = WelcomeActionSchema.safeParse(rawRequest);
    if (!validation.success) {
      return new Response(JSON.stringify({
        error: validation.error.format()
      }), {
        status: 400,
        headers: corsHeaders
      });
    }
    const actionRequest = validation.data;
    if (!RESEND_API_KEY) {
      throw new Error("Missing RESEND_API_KEY");
    }
    const user = await supabase.from("companies").select("*").eq("user_id", actionRequest.user_id).single();
    if (!!user.error || !user.data) {
      return new Response();
    }
    const { subject, template } = actionTemplates[actionRequest.action];
    const templateData = buildTemplateData({
      user: user.data
    });
    if (templateData.email) {
      await sendEmail({
        to: templateData.email,
        subject: subject,
        html: template(templateData)
      });
    }
    return new Response(JSON.stringify({
      success: true
    }), {
      status: 200,
      headers: corsHeaders
    });
  } catch (error) {
    console.error("Error sending email:", error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
};
// Add helper function to build template data
function buildTemplateData(entities) {
  const { user } = entities;
  return {
    name: user.legal_name,
    email: user.personal_email || user.billing_email
  };
}
serve(handler);
