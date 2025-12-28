import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@13.10.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ENV } from "./.envs.ts";
import {
  handleSubscriptionCreated,
  handleSubscriptionDeleted,
  handleSubscriptionPaused,
  handleSubscriptionUpdated,
} from "./handlers/index.ts";
serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const body = await req.text();
  let event, stripe;
  try {
    stripe = new Stripe(ENV.STRIPE_API_KEY, {
      apiVersion: "2024-06-20",
    });
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      ENV.STRIPE_SUBSCRIPTION_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("⚠️  Webhook signature verification failed:", err.message);
    return new Response(`Webhook Error: ${err.message}`, {
      status: 400,
    });
  }
  const supabase = createClient(
    ENV.SUPABASE_URL,
    ENV.SUPABASE_SERVICE_ROLE_KEY
  );
  const context = {
    stripe,
    supabase,
  };
  console.log("Processing webhook event", {
    eventType: event.type,
    eventId: event.id,
    subscriptionId: event.data?.object?.id,
  });
  try {
    switch (event.type) {
      case "customer.subscription.created":
        await handleSubscriptionCreated(event, context);
        break;
      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(event, context);
        break;
      case "customer.subscription.paused":
        await handleSubscriptionPaused(event, context);
        break;
      case "customer.subscription.updated":
        await handleSubscriptionUpdated(event, context);
        break;
      default:
        console.log(`Unhandled event type: ${event.type}`, {
          eventId: event.id,
          eventType: event.type,
        });
    }
    console.log("Successfully processed webhook event", {
      eventType: event.type,
      eventId: event.id,
    });
    return new Response("ok", {
      status: 200,
    });
  } catch (error) {
    console.error("Event processing error:", error, {
      context: "event_processing",
      eventType: event.type,
      eventId: event.id,
      subscriptionId: event.data?.object?.id,
    });
    // Return 500 to indicate server error, which will cause Stripe to retry
    return new Response(`Internal Server Error: ${error.message}`, {
      status: 500,
    });
  }
});
