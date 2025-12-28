/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
export function getEnv() {
  return {
    // Supabase Configuration
    SUPABASE_URL: Deno.env.get("SUPABASE_URL") || "",
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
    // Wise Configuration
    WISE_WEBHOOK_SECRET: Deno.env.get("WISE_WEBHOOK_SECRET") || "",
    WISE_WEBHOOK_SECRET_TEST: Deno.env.get("WISE_WEBHOOK_SECRET_TEST") || ""
  };
}
