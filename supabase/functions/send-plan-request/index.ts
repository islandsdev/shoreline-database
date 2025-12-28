import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { Resend } from "npm:resend@2.0.0";
const resend = new Resend(Deno.env.get("RESEND_API_KEY"));
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
const handler = async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const { companyName, companyEmail, selectedPlan, hiringCountry, currency } = await req.json();
    const emailResponse = await resend.emails.send({
      from: "Lovable <onboarding@resend.dev>",
      to: [
        "olga@islandshq.xyz"
      ],
      subject: `New Plan Request: ${selectedPlan} - ${companyName}`,
      html: `
        <h1>New Plan Request</h1>
        <p>A new plan request has been submitted:</p>
        <ul>
          <li><strong>Company:</strong> ${companyName}</li>
          <li><strong>Company Email:</strong> ${companyEmail}</li>
          <li><strong>Selected Plan:</strong> ${selectedPlan}</li>
          <li><strong>Hiring Country:</strong> ${hiringCountry}</li>
          <li><strong>Currency:</strong> ${currency}</li>
        </ul>
      `
    });
    return new Response(JSON.stringify(emailResponse), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders
      }
    });
  } catch (error) {
    console.error("Error sending plan request email:", error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders
      }
    });
  }
};
serve(handler);
