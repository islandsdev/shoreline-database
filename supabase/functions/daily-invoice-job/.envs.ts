/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
console.log(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
export const ENV = {
  // Supabase Configuration
  SUPABASE_URL: Deno.env.get("SUPABASE_URL") || "",
  SUPABASE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
  // Stripe Configuration
  STRIPE_API_KEY: Deno.env.get("STRIPE_API_KEY"),
  WISE_API_KEY: Deno.env.get("WISE_API_KEY"),
  WISE_BALANCE_ID: Deno.env.get("WISE_BALANCE_ID"),
  WISE_PROFILE_ID: Deno.env.get("WISE_PROFILE_ID"),
  // Environment Configuration
  NODE_ENV: Deno.env.get("NODE_ENV") || "development",
  // Batch Processing Configuration
  BATCH_SIZE: parseInt(Deno.env.get("BATCH_SIZE") || "5"),
  INTER_BATCH_DELAY: parseInt(Deno.env.get("INTER_BATCH_DELAY") || "100"),
  // Retry Configuration
  MAX_RETRIES: parseInt(Deno.env.get("MAX_RETRIES") || "3"),
  RETRY_DELAY: parseInt(Deno.env.get("RETRY_DELAY") || "1000"),
  // Stripe Invoice Configuration
  STRIPE_INVOICE_DAYS_UNTIL_DUE: parseInt(Deno.env.get("STRIPE_INVOICE_DAYS_UNTIL_DUE") || "7"),
  STRIPE_CURRENCY: Deno.env.get("STRIPE_CURRENCY") || "usd",
  // Logging Configuration
  ENABLE_DEBUG_LOGGING: Deno.env.get("ENABLE_DEBUG_LOGGING") === "true",
  LOG_LEVEL: Deno.env.get("LOG_LEVEL") || "info",
};
