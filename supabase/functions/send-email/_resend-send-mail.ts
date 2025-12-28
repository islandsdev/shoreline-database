const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RESEND_FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL");
export async function sendEmail(emailData) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${RESEND_API_KEY}`
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      ...emailData
    })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || "Failed to send email");
  return data;
}
