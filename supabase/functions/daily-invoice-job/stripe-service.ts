import { getConfig } from "./config.ts";
const config = getConfig();
export async function createInvoiceAndItems(
  STRIPE_API_KEY1,
  customerId,
  items
) {
  try {
    let invoice = await createInvoice(STRIPE_API_KEY1, customerId);
    await createInvoiceItems(STRIPE_API_KEY1, customerId, invoice, items);
    invoice = await finalizeAndPayInvoice(STRIPE_API_KEY1, invoice);
    return invoice;
  } catch (error) {
    console.error(`Error creating invoice for customer ${customerId}:`, error);
    throw new Error(`Invoice creation failed: ${error.message}`);
  }
}
export async function createInvoice(STRIPE_API_KEY1, customerId) {
  const body = new URLSearchParams({
    customer: customerId,
    collection_method: "charge_automatically",
    auto_advance: "true",
  });
  const res = await fetch("https://api.stripe.com/v1/invoices", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_API_KEY1}`,
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
export async function createInvoiceItems(
  STRIPE_API_KEY1,
  customerId,
  invoice,
  items
) {
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
          Authorization: `Bearer ${STRIPE_API_KEY1}`,
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
export async function finalizeAndPayInvoice(STRIPE_API_KEY, invoice) {
  try {
    // Step 1: Finalize the invoice
    const finalizeRes = await fetch(
      `https://api.stripe.com/v1/invoices/${invoice.id}/finalize`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${STRIPE_API_KEY}`,
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
    // Step 2: Attempt to pay the invoice immediately
    const payRes = await fetch(
      `https://api.stripe.com/v1/invoices/${invoice.id}/pay`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${STRIPE_API_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
      }
    );
    const payData = await payRes.json();
    if (!payRes.ok) {
      throw new Error(
        payData.error?.message ||
          `Invoice payment failed with status ${payRes.status}`
      );
    }

    const x = { ...payData, invoice_link: payData.hosted_invoice_url };

    return x;
  } catch (error) {
    console.error(`Error finalizing/sending invoice ${invoice.id}:`, error);
    throw new Error(`Invoice finalization/payment failed: ${error.message}`);
  }
}
