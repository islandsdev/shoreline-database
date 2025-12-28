/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
export const ENV = {
  // Supabase Configuration
  SUPABASE_URL: Deno.env.get("SUPABASE_URL") || "",
  SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
  // Stripe Configuration
  STRIPE_API_KEY: Deno.env.get("STRIPE_API_KEY"),
  STRIPE_SUBSCRIPTION_WEBHOOK_SECRET: Deno.env.get("STRIPE_SUBSCRIPTION_WEBHOOK_SECRET"),
};
