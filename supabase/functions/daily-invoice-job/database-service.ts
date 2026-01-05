import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
/**
 * Normalizes invoice status to either "paid" or "processing"
 * @param status - The raw status from the payment provider
 * @param provider - The payment provider ("Stripe" or "Wise")
 * @returns Normalized status: "paid" or "processing"
 */ function normalizeInvoiceStatus(status, provider) {
  if (!status) {
    return "processing";
  }
  const normalizedStatus = status.toLowerCase();
  if (provider === "Stripe") {
    // Stripe invoice statuses: draft, open, paid, uncollectible, void
    // Only "paid" maps to "paid", everything else is "processing"
    return normalizedStatus === "paid" ? "paid" : "processing";
  } else if (provider === "Wise") {
    // Wise invoice statuses: PUBLISHED, PAID, etc.
    // Only "paid" maps to "paid", everything else is "processing"
    return normalizedStatus === "paid" ? "paid" : "processing";
  }
  // Default to processing for unknown providers or statuses
  return "processing";
}
export class DatabaseService {
  supabase;
  constructor(supabaseUrl, supabaseKey) {
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }
  async getActiveTeamMemberIds() {
    const { data: activeMembers, error } = await this.supabase
      .from("team_members")
      .select("team_member_id")
      .eq("is_active", true);
    if (error) throw error;
    return activeMembers?.map((m) => m.team_member_id) || [];
  }
  async getPaystubs(scheduleIds) {
    const activeTeamMemberIds = await this.getActiveTeamMemberIds();
    if (activeTeamMemberIds.length === 0) {
      return [];
    }
    const { data: paystubs, error: paystubError } = await this.supabase
      .from("payments")
      .select(
        `
    *,
    employee:team_member_id (
      team_member_id,
      first_name,
      last_name,
      employment_type,
      company:company_id (
        id,
        legal_name,
        customer_stripe_id,
        billing_email
      ),
      rrsp_plan:rrsp_plan_id(*)
    ),
    payroll_schedule:payroll_schedules(*)
  `
      )
      .in("payroll_schedule_id", scheduleIds)
      .is("invoice_id", null)
      .in("team_member_id", activeTeamMemberIds)
      .order("first_name", {
        foreignTable: "employee",
        ascending: true,
      })
      .order("last_name", {
        foreignTable: "employee",
        ascending: true,
      });
    if (paystubError) throw paystubError;
    return paystubs || [];
  }
  async getOneTimePayments(scheduleIds) {
    const activeTeamMemberIds = await this.getActiveTeamMemberIds();
    if (activeTeamMemberIds.length === 0) {
      return [];
    }
    const { data: oneTimePayments, error } = await this.supabase
      .from("wip_one_time_payments")
      .select(
        `
    *,
    employee:team_member_id (
      team_member_id,
      first_name,
      last_name,
      employment_type,
      company:company_id (
        id,
        legal_name,
        payment_method,
        customer_stripe_id
      )
    ),
    payroll_schedule:payroll_schedules(*)
  `
      )
      .in("payroll_schedule_id", scheduleIds)
      .is("invoice_id", null)
      .in("team_member_id", activeTeamMemberIds)
      .order("first_name", {
        foreignTable: "employee",
        ascending: true,
      })
      .order("last_name", {
        foreignTable: "employee",
        ascending: true,
      })
      .order("payment_type", {
        ascending: true,
      });
    if (error) {
      throw new Error(`Error fetching one time payments: ${error.message}`);
    }
    return oneTimePayments || [];
  }
  async getScheduleIds() {
    const targetDate = new Date();
    targetDate.setDate(targetDate.getDate() + 14);
    const targetDateStr1 = targetDate.toISOString().split("T")[0];
    console.log(`Fetching data with start_date before: ${targetDateStr1}`);
    const { data: schedules, error: scheduleError } = await this.supabase
      .from("payroll_schedules")
      .select("id")
      .lte("end_date", targetDateStr1);
    if (scheduleError) throw scheduleError;
    if (!schedules?.length)
      return {
        data: [],
        error: null,
      };
    // Extract the matching schedule IDs
    const scheduleIds = schedules.map((s) => s.id);
    return scheduleIds;
  }
  async getForexRate() {
    const { data: rates, error } = await this.supabase
      .from("forex_rates")
      .select("*")
      .order("created_at", {
        ascending: false,
      })
      .limit(1);
    if (error) {
      throw new Error(`Error fetching forex rate: ${error.message}`);
    }
    return rates[0];
  }
  async getGroupInvestmentTopups() {
    const { data: topups, error } = await this.supabase
      .from("topups")
      .select("*")
      .eq("type", "Group Investment Plan")
      .eq("status", "Completed");
    if (error) {
      throw new Error(`Error group investment plans: ${error.message}`);
    }
    return topups;
  }
  async saveInvoice(
    companyId,
    paystubIds,
    oneTimePaymentIds,
    invoice,
    provider = "Stripe"
  ) {
    // Determine invoice number and amount based on provider
    let invoiceNumber = null;
    let amount = null;
    if (provider === "Stripe") {
      invoiceNumber = invoice.number;
      amount = invoice.amount_due / 100; // Stripe amounts are in cents
    } else if (provider === "Wise") {
      invoiceNumber = invoice.invoice_number; // Use Wise invoice number
      amount = invoice.amount;
    }
    // Normalize the invoice status
    const normalizedStatus = normalizeInvoiceStatus(invoice.status, provider);
    // Insert into main invoices table
    const { data: invoiceData, error: invoiceError } = await this.supabase
      .from("invoices")
      .insert({
        company_id: companyId,
        invoice_link: invoice.invoice_link,
        invoice_number: invoiceNumber,
        status: normalizedStatus,
        amount: amount,
        provider: provider,
      })
      .select("id")
      .single();
    if (invoiceError) {
      throw new Error(`Error saving invoice: ${invoiceError.message}`);
    }
    const invoiceId = invoiceData.id;
    // Save provider-specific invoice data
    if (provider === "Stripe") {
      const { error: stripeError } = await this.supabase
        .from("stripe_invoices")
        .insert({
          invoice_id: invoiceId,
          stripe_invoice_id: invoice.id,
          stripe_customer_id: invoice.customer,
          stripe_created_at: new Date(invoice.created * 1000),
          raw_payload: invoice,
        });
      if (stripeError) {
        throw new Error(`Error saving Stripe invoice: ${stripeError.message}`);
      }
    } else if (provider === "Wise") {
      const { error: wiseError } = await this.supabase
        .from("wise_invoices")
        .insert({
          invoice_id: invoiceId,
          wise_invoice_id: invoice.wise_invoice_id,
          profile_id: invoice.profile_id,
          payment_request_id: invoice.payment_request_id,
          raw_payload: invoice.raw_payload,
        });
      if (wiseError) {
        throw new Error(`Error saving Wise invoice: ${wiseError.message}`);
      }
    }
    // Update payments and one-time payments with invoice_id
    if (paystubIds && paystubIds.length > 0) {
      const { error: paystubError } = await this.supabase
        .from("payments")
        .update({
          invoice_id: invoiceId,
          status: "processing",
        })
        .in("id", paystubIds);
      if (paystubError) {
        throw new Error(`Error updating payments: ${paystubError.message}`);
      }
    }
    if (oneTimePaymentIds && oneTimePaymentIds.length > 0) {
      const { error: oneTimeError } = await this.supabase
        .from("wip_one_time_payments")
        .update({
          invoice_id: invoiceId,
          status: "processing",
        })
        .in("id", oneTimePaymentIds);
      if (oneTimeError) {
        throw new Error(
          `Error updating one-time payments: ${oneTimeError.message}`
        );
      }
    }
    return invoiceId;
  }
}
