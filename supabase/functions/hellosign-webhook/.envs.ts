/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
// This file centralizes all environment variables used in the daily-job function
export const ENV = {
  // Supabase Configuration
  SUPABASE_URL: Deno.env.get("SUPABASE_URL") || "",
  SUPABASE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
};
// Validation function to ensure required environment variables are set
export function validateEnvironment() {
  const requiredVars = [
    "SUPABASE_URL",
    "SUPABASE_KEY"
  ];
  const missingVars = requiredVars.filter((varName)=>!ENV[varName]);
  if (missingVars.length > 0) {
    throw new Error(`Missing required environment variables: ${missingVars.join(", ")}`);
  }
}
