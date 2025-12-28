import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { ENV, validateEnvironment } from "./.envs.ts";
import { DatabaseService } from "./database-service.ts";
import { HelloSignService } from "./hello-sign-service.ts";
// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    validateEnvironment();
    const dbService = new DatabaseService(ENV.SUPABASE_URL, ENV.SUPABASE_KEY);
    const helloSignService = new HelloSignService(ENV.HELLOSIGN_API_KEY);
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        success: false,
        error: 'Only POST method is allowed'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 405
      });
    }
    // Send document with template
    const reqBody = await req.json();
    const { subject, message, templateId, signers, customFields, companyId, employeeId, type } = reqBody;
    const result = await helloSignService.sendDocumentWithTemplate({
      subject,
      message,
      templateId,
      signers,
      customFields,
    });
    await dbService.saveHelloSignDocument(result.signature_request, companyId, employeeId, type);
    return new Response(JSON.stringify({
      success: true,
      data: result
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Function error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message || 'Internal server error'
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
