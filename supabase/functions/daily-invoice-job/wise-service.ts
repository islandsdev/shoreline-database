export async function createWiseInvoice(
  WISE_API_KEY1,
  WISE_BALANCE_ID1,
  WISE_PROFILE_ID1,
  items
) {
  try {
    const lineitems = items.map((item, index) => ({
      name: item.description,
      unitPrice: {
        value: item.amount,
        currency: "USD",
      },
      quantity: 1,
      tax: null,
      rank: index,
    }));
    const issueDate = new Date();
    const dueAt = new Date(issueDate);
    dueAt.setDate(dueAt.getDate() + 7);
    const body = {
      requestType: "INVOICE",
      selectedPaymentMethods: ["WISE_ACCOUNT", "ACCOUNT_DETAILS"],
      balanceId: WISE_BALANCE_ID1,
      dueAt,
      issueDate,
      payer: {
        name: "test full name",
        email: "testemail@gmail.com",
        locale: "en",
      },
      lineItems: lineitems,
    };
    const res = await fetch(
      `https://wise.com/gateway/v2/profiles/${WISE_PROFILE_ID1}/acquiring/payment-requests`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${WISE_API_KEY1}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }
    );
    const data = await res.json();
    if (!res.ok) {
      throw new Error(
        data.error?.message ||
          `Invoice creation failed with status ${res.status}`
      );
    }
    const invoiceId = data.id;
    const body2 = {
      status: "PUBLISHED",
    };
    const res2 = await fetch(
      `https://wise.com/gateway/v1/profiles/${WISE_PROFILE_ID1}/acquiring/payment-requests/${invoiceId}/status`,
      {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${WISE_API_KEY1}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body2),
      }
    );

    if (!res2.ok) {
      const errorData = await res2.json();
      throw new Error(
        errorData.error?.message ||
          `Invoice publishing failed with status ${res2.status}`
      );
    }

    // Calculate total amount from line items
    const totalAmount = items.reduce((sum, item) => sum + item.amount, 0);

    // Extract invoice number from Wise API response
    // The invoice number might be in data.invoiceNumber, data.number, or similar field
    const invoiceNumber = data.reference;

    // Return invoice data for database storage
    return {
      wise_invoice_id: invoiceId,
      invoice_number: invoiceNumber,
      invoice_link: data.link,
      profile_id: WISE_PROFILE_ID1,
      payment_request_id: invoiceId,
      amount: totalAmount,
      status: "PUBLISHED",
      raw_payload: data,
      created_at: new Date(),
    };
  } catch (error) {
    throw new Error(`Invoice creation failed: ${error.message}`);
  }
}
