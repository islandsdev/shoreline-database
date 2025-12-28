/// <reference path="./deno.d.ts" />
// Environment Variables Configuration
export const ENV = {
  // Stripe Configuration
  STRIPE_API_KEY: Deno.env.get("STRIPE_API_KEY"),
};
