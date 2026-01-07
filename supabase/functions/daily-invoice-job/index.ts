import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { DatabaseService } from "./database-service.ts";
import { createInvoiceAndItemsForAllCompanies } from "./invoice-service.ts";
import { groupByCompany } from "./utils.ts";
import { ENV } from "./.envs.ts";
// CORS Headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
async function handler(req) {
  // Handle preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }
  try {
    return jsonResponse(
      {
        message: "CRON JOB PAUSED",
        total_processed: 0,
      },
      200
    );
    const dbService = new DatabaseService(ENV.SUPABASE_URL, ENV.SUPABASE_KEY);
    // Fetch data concurrently
    const scheduleIds = await dbService.getScheduleIds();
    const [paystubs, oneTimePayments, forexRate, groupInvestmentTopups] =
      await Promise.all([
        dbService.getPaystubs(scheduleIds),
        dbService.getOneTimePayments(scheduleIds),
        dbService.getForexRate(),
        dbService.getGroupInvestmentTopups(),
      ]);
    if (
      (!paystubs || paystubs.length === 0) &&
      (!oneTimePayments || oneTimePayments.length === 0)
    ) {
      console.log(`Nothing found to process`);
      return jsonResponse(
        {
          message: "Nothing found to process",
          total_processed: 0,
        },
        200
      );
    }
    const companiesData = groupByCompany(
      paystubs,
      oneTimePayments,
      forexRate?.rate,
      groupInvestmentTopups
    );
    if (companiesData.length === 0) {
      return jsonResponse(
        {
          message: "No company data found to process",
          total_processed: 0,
        },
        200
      );
    }
    console.log(
      `Starting invoice processing for ${companiesData.length} companies`
    );
    const startTime = Date.now();
    // Process invoices with the refactored service
    const processingResult = await createInvoiceAndItemsForAllCompanies(
      dbService,
      companiesData
    );
    const endTime = Date.now();
    const processingTime = endTime - startTime;
    console.log(`Invoice processing completed in ${processingTime}ms`);
    return jsonResponse({
      message: "Invoice processing completed successfully",
      processing_time_ms: processingTime,
      companies_data: companiesData,
    });
  } catch (error) {
    console.error("Error processing request:", error);
    // Return more detailed error information
    return jsonResponse(
      {
        error: "Internal Server Error",
        message: error.message || "An unexpected error occurred",
        timestamp: new Date().toISOString(),
      },
      500
    );
  }
}
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
serve(handler);
// Default export for Deno Deploy compatibility
export default serve;
