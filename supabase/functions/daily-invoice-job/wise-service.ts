import { ENV } from "./.envs.ts";
export async function createWiseInvoice(items, companyName, companyEmail) {
  try {
    console.log("=== Wise Invoice Creation Started ===");
    console.log("Input parameters:", {
      hasApiKey: !!ENV.WISE_API_KEY,
      balanceId: ENV.WISE_BALANCE_ID,
      profileId: ENV.WISE_PROFILE_ID,
      itemsCount: items?.length || 0,
      companyName: companyName,
      companyEmail: companyEmail,
    });
    // Validate inputs
    if (!items || items.length === 0) {
      throw new Error("No items provided for invoice");
    }
    if (!companyName) {
      console.warn("Warning: companyName is missing or empty");
    }
    if (!companyEmail) {
      console.warn("Warning: companyEmail is missing or empty");
    }
    const lineitems = items.map((item, index) => {
      const lineItem = {
        name: item.description,
        unitPrice: {
          value: item.amount,
          currency: "USD",
        },
        quantity: 1,
        tax: null,
        rank: index,
      };
      return lineItem;
    });
    const issueDate = new Date();
    const dueAt = new Date(issueDate);
    dueAt.setDate(dueAt.getDate() + 7);
    console.log("Date information:", {
      issueDate: issueDate.toISOString(),
      dueAt: dueAt.toISOString(),
    });
    const body = {
      requestType: "INVOICE",
      selectedPaymentMethods: ["WISE_ACCOUNT", "ACCOUNT_DETAILS"],
      balanceId: ENV.WISE_BALANCE_ID,
      dueAt: dueAt.toISOString(),
      issueDate: issueDate.toISOString(),
      payer: {
        name: companyName || "Company",
        email: companyEmail || "billing@company.com",
        locale: "en",
      },
      lineItems: lineitems,
    };
    console.log(
      "Request body being sent to Wise API:",
      JSON.stringify(body, null, 2)
    );
    console.log(
      "Request URL:",
      `https://wise.com/gateway/v2/profiles/${ENV.WISE_PROFILE_ID}/acquiring/payment-requests`
    );
    const res = await fetch(
      `https://wise.com/gateway/v2/profiles/${ENV.WISE_PROFILE_ID}/acquiring/payment-requests`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${ENV.WISE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      }
    );
    console.log("Wise API Response Status:", res.status, res.statusText);
    const data = await res.json();
    console.log("Wise API Response Data:", JSON.stringify(data, null, 2));
    if (!res.ok) {
      console.error("Wise API Error Details:", {
        status: res.status,
        statusText: res.statusText,
        error: data,
        errorMessage: data.error?.message,
        errorCode: data.error?.code,
        errors: data.errors,
      });
      throw new Error(
        data.error?.message ||
          data.message ||
          `Invoice creation failed with status ${res.status}: ${JSON.stringify(
            data
          )}`
      );
    }
    const invoiceId = data.id;
    console.log("Invoice created successfully with ID:", invoiceId);
    const body2 = {
      status: "PUBLISHED",
    };
    console.log(
      "Publishing invoice with body:",
      JSON.stringify(body2, null, 2)
    );
    console.log(
      "Publish URL:",
      `https://wise.com/gateway/v1/profiles/${ENV.WISE_PROFILE_ID}/acquiring/payment-requests/${invoiceId}/status`
    );
    const res2 = await fetch(
      `https://wise.com/gateway/v1/profiles/${ENV.WISE_PROFILE_ID}/acquiring/payment-requests/${invoiceId}/status`,
      {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${ENV.WISE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body2),
      }
    );
    console.log("Publish Response Status:", res2.status, res2.statusText);
    const publishData = await res2.json();
    console.log("Publish Response Data:", JSON.stringify(publishData, null, 2));
    if (!res2.ok) {
      console.error("Invoice Publishing Error Details:", {
        status: res2.status,
        statusText: res2.statusText,
        error: publishData,
        errorMessage: publishData.error?.message,
        errorCode: publishData.error?.code,
        errors: publishData.errors,
      });
      const errorData = publishData;
      throw new Error(
        errorData.error?.message ||
          errorData.message ||
          `Invoice publishing failed with status ${
            res2.status
          }: ${JSON.stringify(errorData)}`
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
      profile_id: ENV.WISE_PROFILE_ID,
      payment_request_id: invoiceId,
      amount: totalAmount,
      status: "PUBLISHED",
      raw_payload: data,
      created_at: new Date(),
    };
  } catch (error) {
    console.error("=== Wise Invoice Creation Error ===");
    console.error("Error message:", error.message);
    console.error("Error stack:", error.stack);
    if (error.response) {
      console.error("Error response:", error.response);
    }
    throw new Error(`Invoice creation failed: ${error.message}`);
  }
}
