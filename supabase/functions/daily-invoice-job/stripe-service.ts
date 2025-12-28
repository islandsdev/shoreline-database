import { getConfig } from "./config.ts";
import { ENV } from "./.envs.ts";
const config = getConfig();
export async function createInvoiceAndItems(customerId, items) {
  try {
    let invoice = await createInvoice(customerId);
    await createInvoiceItems(customerId, invoice, items);
    invoice = await finalizeInvoice(invoice);
    return invoice;
  } catch (error) {
    console.error(`Error creating invoice for customer ${customerId}:`, error);
    throw new Error(`Invoice creation failed: ${error.message}`);
  }
}
export async function createInvoice(customerId) {
  const body = new URLSearchParams({
    customer: customerId,
    collection_method: "send_invoice",
    auto_advance: "true",
  });
  const res = await fetch("https://api.stripe.com/v1/invoices", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ENV.STRIPE_API_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(
      data.error?.message || `Invoice creation failed with status ${res.status}`
    );
  }
  return data;
}
export async function createInvoiceItems(customerId, invoice, items) {
  try {
    for (const item of items) {
      const body = new URLSearchParams({
        invoice: invoice.id,
        customer: customerId,
        amount: Math.round(item.amount * 100).toString(),
        description: item.description,
        currency: config.STRIPE_CURRENCY,
      });
      const res = await fetch("https://api.stripe.com/v1/invoiceitems", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${ENV.STRIPE_API_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body,
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(
          data.error?.message ||
            `Invoice item creation failed with status ${res.status}`
        );
      }
    }
  } catch (error) {
    console.error(
      `Error creating invoice items for invoice ${invoice.id}:`,
      error
    );
    throw new Error(`Invoice items creation failed: ${error.message}`);
  }
}
export async function finalizeInvoice(invoice) {
  try {
    // Finalize the invoice (this will send it to the customer for manual payment)
    const finalizeRes = await fetch(
      `https://api.stripe.com/v1/invoices/${invoice.id}/finalize`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${ENV.STRIPE_API_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
      }
    );
    if (!finalizeRes.ok) {
      const finalizeData = await finalizeRes.json();
      throw new Error(
        finalizeData.error?.message ||
          `Invoice finalization failed with status ${finalizeRes.status}`
      );
    }
    const finalizeData = await finalizeRes.json();
    // Return the finalized invoice with the invoice link
    return {
      ...finalizeData,
      invoice_link: finalizeData.hosted_invoice_url,
    };
  } catch (error) {
    console.error(`Error finalizing invoice ${invoice.id}:`, error);
    throw new Error(`Invoice finalization failed: ${error.message}`);
  }
}
