import { getConfig, validateConfig } from "./config.ts";
import { createInvoiceAndItems } from "./stripe-service.ts";
import { createWiseInvoice } from "./wise-service.ts";
const config = getConfig();
// Validate configuration on module load
validateConfig(config);
export async function createInvoiceAndItemsForAllCompanies(dbService, STRIPE_API_KEY1, WISE_API_KEY1, WISE_BALANCE_ID1, WISE_PROFILE_ID1, companiesData) {
  const results = [];
  const errors = [];
  console.log(`Starting invoice processing with batch size: ${config.BATCH_SIZE}, max retries: ${config.MAX_RETRIES}`);
  // Process companies in batches for better scalability
  for(let i = 0; i < companiesData.length; i += config.BATCH_SIZE){
    const batch = companiesData.slice(i, i + config.BATCH_SIZE);
    const batchNumber = Math.floor(i / config.BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(companiesData.length / config.BATCH_SIZE);
    console.log(`Processing batch ${batchNumber}/${totalBatches} with ${batch.length} companies`);
    // Process batch concurrently and wait for all to complete
    const batchPromises = batch.map(async (company)=>{
      try {
        const result = await processCompany(STRIPE_API_KEY1, WISE_API_KEY1, WISE_BALANCE_ID1, WISE_PROFILE_ID1, company, dbService);
        results.push(result);
        return result;
      } catch (error) {
        const errorInfo = {
          company_id: company.company_id,
          company_name: company.company_name,
          status: "error",
          error: error.message,
          timestamp: new Date().toISOString()
        };
        errors.push(errorInfo);
        console.error(`Error processing company ${company.company_name}:`, error);
        return errorInfo;
      }
    });
    // Wait for all companies in this batch to complete before moving to next batch
    await Promise.all(batchPromises);
    console.log(`Batch ${batchNumber}/${totalBatches} completed. Success: ${results.length}, Errors: ${errors.length}`);
    // Add a small delay between batches to prevent overwhelming external APIs
    if (i + config.BATCH_SIZE < companiesData.length) {
      if (config.ENABLE_DEBUG_LOGGING) {
        console.log(`Waiting ${config.INTER_BATCH_DELAY}ms before next batch...`);
      }
      await new Promise((resolve)=>setTimeout(resolve, config.INTER_BATCH_DELAY));
    }
  }
  // Log summary
  console.log(`Processing complete. Success: ${results.length}, Errors: ${errors.length}`);
  return {
    success: results,
    errors: errors,
    total_processed: companiesData.length,
    success_count: results.length,
    error_count: errors.length,
    config_used: {
      batch_size: config.BATCH_SIZE,
      max_retries: config.MAX_RETRIES,
      retry_delay: config.RETRY_DELAY,
      inter_batch_delay: config.INTER_BATCH_DELAY
    }
  };
}
async function processCompany(STRIPE_API_KEY1, WISE_API_KEY1, WISE_BALANCE_ID1, WISE_PROFILE_ID1, company, dbService) {
  try {
    if (company.payment_method === "Stripe") {
      if (!company.company_stripe_id) {
        throw new Error(`Company ${company.company_name} has Stripe payment method but no Stripe customer ID`);
      }
      const invoice = await createInvoiceAndItems(STRIPE_API_KEY1, company.company_stripe_id, company.invoices);
      const invoiceId = await dbService.saveInvoice(company.company_id, company.paystubIds, company.oneTimePaymentIds, invoice, "Stripe");
      return {
        company_id: company.company_id,
        company_name: company.company_name,
        invoice_id: invoiceId,
        provider: "Stripe",
        status: "success",
        timestamp: new Date().toISOString()
      };
    } else if (company.payment_method === "Wise") {
      const wiseInvoice = await createWiseInvoice(WISE_API_KEY1, WISE_BALANCE_ID1, WISE_PROFILE_ID1, company.invoices, company.company_name, company.billing_email);
      const invoiceId = await dbService.saveInvoice(company.company_id, company.paystubIds, company.oneTimePaymentIds, wiseInvoice, "Wise");
      return {
        company_id: company.company_id,
        company_name: company.company_name,
        invoice_id: invoiceId,
        provider: "Wise",
        status: "success",
        timestamp: new Date().toISOString()
      };
    } else {
      throw new Error(`Unknown payment method: ${company.payment_method} for company ${company.company_name}`);
    }
  } catch (error) {
    console.error(`Error processing company ${company.company_name}:`, error);
    throw error; // Re-throw to be caught by the caller
  }
}
