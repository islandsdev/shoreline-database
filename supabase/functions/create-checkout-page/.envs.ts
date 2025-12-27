/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
export function getEnv(isTest = false) {
  return {
    // Stripe Configuration
    STRIPE_API_KEY: isTest ? Deno.env.get("STRIPE_API_KEY_TEST") : Deno.env.get("STRIPE_API_KEY")
  };
}
