import { ValidationError, DatabaseError, StripeError } from "../types.ts";
export async function handleSubscriptionPaused(event, context) {
  const { stripe, supabase } = context;
  const subscription = event.data.object;
  console.log("Processing subscription paused event", {
    subscriptionId: subscription.id,
    customerId: subscription.customer,
    status: subscription.status
  });
  try {
    // Retrieve customer from Stripe
    let customer;
    try {
      customer = await stripe.customers.retrieve(subscription.customer);
    } catch (error) {
      throw new StripeError(`Failed to retrieve customer: ${error.message}`, "customer.subscription.paused", subscription.id, error);
    }
    const { company_id } = customer.metadata;
    // Validate required data
    if (!company_id) {
      throw new ValidationError("Missing company_id in customer metadata", "customer.subscription.paused", subscription.id);
    }
    console.log("Updating plan status to paused", {
      subscriptionId: subscription.id,
      companyId: company_id
    });
    // Update the plan status to paused
    const { error } = await supabase.from("plans").update({
      status: "Paused",
      updated_at: new Date().toISOString()
    }).eq("company_id", company_id).eq("stripe_subscription_id", subscription.id);
    if (error) {
      throw new DatabaseError(`Failed to update plan status to paused: ${error.message}`, "customer.subscription.paused", "update", subscription.id, company_id, error);
    }
    console.log("Successfully paused subscription plan", {
      subscriptionId: subscription.id,
      companyId: company_id
    });
  } catch (error) {
    console.error("Error in subscription paused handler:", error, {
      eventType: "customer.subscription.paused",
      subscriptionId: subscription.id,
      customerId: subscription.customer
    });
    throw error; // Re-throw to be handled by the main handler
  }
}
