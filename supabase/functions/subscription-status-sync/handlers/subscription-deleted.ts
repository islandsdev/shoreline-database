import { ValidationError, DatabaseError, StripeError } from "../types.ts";
export async function handleSubscriptionDeleted(event, context) {
  const { stripe, supabase } = context;
  const subscription = event.data.object;
  const { teamMemberId, type } = subscription.metadata || {};
  console.log("Processing subscription deleted event", {
    subscriptionId: subscription.id,
    customerId: subscription.customer,
    status: subscription.status
  });
  // Retrieve customer from Stripe
  let customer;
  try {
    customer = await stripe.customers.retrieve(subscription.customer);
  } catch (error) {
    throw new StripeError(`Failed to retrieve customer: ${error.message}`, "customer.subscription.deleted", subscription.id, error);
  }
  try {
    // Retrieve customer from Stripe
    let customer;
    try {
      customer = await stripe.customers.retrieve(subscription.customer);
    } catch (error) {
      throw new StripeError(`Failed to retrieve customer: ${error.message}`, "customer.subscription.deleted", subscription.id, error);
    }
    const { company_id } = customer.metadata;
    if (type && type == 'topup') {
      if (!teamMemberId) {
        throw new ValidationError("Missing teamMemberId in customer metadata", "customer.subscription.created", subscription.id);
      }
      const prodId = subscription.plan.product;
      let type;
      if (prodId == 'prod_TRkpBfAM4lIls0' || prodId == 'prod_SbgEBjaFNfojCU') type = 'Benefits';
      else type = 'Group Investment Plan';
      // Insert plan into database
      console.log("teamMemberId");
      console.log(teamMemberId);
      console.log("company_id");
      console.log(company_id);
      const { data, error } = await supabase.from("topups").update({
        status: "Cancelled"
      }).eq("type", type).eq("team_member_id", teamMemberId).eq("company_id", company_id);
      console.log("type", type);
      if (error) {
        throw new DatabaseError(`Failed to insert plan: ${error.message}`, "customer.subscription.created", "insert", subscription.id, company_id, error);
      }
    } else {
      console.log(">>2");
      // Validate required data
      if (!company_id) {
        throw new ValidationError("Missing company_id in customer metadata", "customer.subscription.deleted", subscription.id);
      }
      console.log("Updating plan status to cancelled", {
        subscriptionId: subscription.id,
        companyId: company_id
      });
      // Update the plan status to cancelled/deleted
      const { error } = await supabase.from("plans").update({
        status: "Cancelled",
        updated_at: new Date().toISOString()
      }).eq("company_id", company_id).eq("stripe_subscription_id", subscription.id);
      if (error) {
        throw new DatabaseError(`Failed to update plan status: ${error.message}`, "customer.subscription.deleted", "update", subscription.id, company_id, error);
      }
      console.log("Successfully cancelled subscription plan", {
        subscriptionId: subscription.id,
        companyId: company_id
      });
    }
  } catch (error) {
    console.error("Error in subscription deleted handler:", error, {
      eventType: "customer.subscription.deleted",
      subscriptionId: subscription.id,
      customerId: subscription.customer
    });
    throw error; // Re-throw to be handled by the main handler
  }
}
