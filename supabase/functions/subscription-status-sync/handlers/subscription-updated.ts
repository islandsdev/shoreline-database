import { ValidationError, DatabaseError, StripeError } from "../types.ts";
export async function handleSubscriptionUpdated(event, context) {
  const { stripe, supabase } = context;
  const subscription = event.data.object;
  console.log("Processing subscription updated event", {
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
      throw new StripeError(`Failed to retrieve customer: ${error.message}`, "customer.subscription.updated", subscription.id, error);
    }
    const { company_id } = customer.metadata;
    const { planName, term, count } = subscription.metadata || {};
    // Validate required data
    if (!company_id) {
      throw new ValidationError("Missing company_id in customer metadata", "customer.subscription.updated", subscription.id);
    }
    if (!subscription.items?.data?.[0]?.price) {
      throw new ValidationError("Missing price information in subscription", "customer.subscription.updated", subscription.id);
    }
    // Prepare update data
    const updateData = {
      plan_name: planName ?? "",
      status: subscription.status === "active" ? "Completed" : subscription.status,
      price: subscription.items.data[0].price.unit_amount / 100,
      term: subscription.items.data[0].price.recurring?.interval === "year" ? "Yearly" : "Monthly",
      number_of_employees: count ?? 1,
      updated_at: new Date().toISOString()
    };
    console.log("Updating existing plan", {
      subscriptionId: subscription.id,
      companyId: company_id,
      updateData
    });
    // Update the existing plan with new information
    const { error } = await supabase.from("plans").update(updateData).eq("company_id", company_id).eq("stripe_subscription_id", subscription.id);
    if (error) {
      throw new DatabaseError(`Failed to update plan: ${error.message}`, "customer.subscription.updated", "update", subscription.id, company_id, error);
    }
    console.log("Successfully updated subscription plan", {
      subscriptionId: subscription.id,
      companyId: company_id,
      planName: updateData.plan_name
    });
  } catch (error) {
    console.error("Error in subscription updated handler:", error, {
      eventType: "customer.subscription.updated",
      subscriptionId: subscription.id,
      customerId: subscription.customer
    });
    throw error; // Re-throw to be handled by the main handler
  }
}
