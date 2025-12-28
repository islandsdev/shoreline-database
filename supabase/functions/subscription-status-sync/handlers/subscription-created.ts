import { ValidationError, DatabaseError, StripeError } from "../types.ts";
export async function handleSubscriptionCreated(event, context) {
  const { stripe, supabase } = context;
  const subscription = event.data.object;
  console.log("Processing subscription created event", {
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
      throw new StripeError(`Failed to retrieve customer: ${error.message}`, "customer.subscription.created", subscription.id, error);
    }
    const { company_id } = customer.metadata;
    const { planName, count, teamMemberId, type, startDate } = subscription.metadata || {};
    if (!company_id) {
      throw new ValidationError("Missing company_id in customer metadata", "customer.subscription.created", subscription.id);
    }
    if (type && type == 'topup') {
      if (!teamMemberId) {
        throw new ValidationError("Missing teamMemberId in customer metadata", "customer.subscription.created", subscription.id);
      }
      const prodId = subscription.plan.product;
      let type;
      if (prodId == 'prod_TRkpBfAM4lIls0' || prodId == 'prod_SbgEBjaFNfojCU') type = 'Benefits';
      else type = 'Group Investment Plan';
      const topupData = {
        type,
        company_id: company_id,
        team_member_id: teamMemberId,
        status: subscription.status === "active" ? "Completed" : subscription.status,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      console.log("Inserting new plan", {
        subscriptionId: subscription.id,
        companyId: company_id,
        topupData
      });
      // Insert plan into database
      const { error } = await supabase.from("topups").insert(topupData);
      if (error) {
        throw new DatabaseError(`Failed to insert plan: ${error.message}`, "customer.subscription.created", "insert", subscription.id, company_id, error);
      }
      if (type == 'Benefits') {
        await supabase.from("team_members").update({
          benefits_start_date: startDate
        }).eq("team_member_id", teamMemberId);
      }
    } else {
      if (!subscription.items?.data?.[0]?.price) {
        throw new ValidationError("Missing price information in subscription", "customer.subscription.created", subscription.id);
      }
      // Prepare plan data
      const planData = {
        company_id,
        plan_name: planName ?? "",
        status: subscription.status === "active" ? "Completed" : subscription.status,
        price: subscription.items.data[0].price.unit_amount / 100,
        term: subscription.items.data[0].price.recurring?.interval === "year" ? "Yearly" : "Monthly",
        number_of_employees: count ?? 1,
        stripe_subscription_id: subscription.id,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      console.log("Inserting new plan", {
        subscriptionId: subscription.id,
        companyId: company_id,
        planData
      });
      // Insert plan into database
      const { error } = await supabase.from("plans").insert(planData);
      if (error) {
        throw new DatabaseError(`Failed to insert plan: ${error.message}`, "customer.subscription.created", "insert", subscription.id, company_id, error);
      }
      console.log("Successfully created subscription plan", {
        subscriptionId: subscription.id,
        companyId: company_id,
        planName: planData.plan_name
      });
    }
  // Validate required data
  } catch (error) {
    console.error("Error in subscription created handler:", error, {
      eventType: "customer.subscription.created",
      subscriptionId: subscription.id,
      customerId: subscription.customer
    });
    throw error; // Re-throw to be handled by the main handler
  }
}
