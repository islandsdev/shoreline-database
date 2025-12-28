// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
// Helper to parse Slack's x-www-form-urlencoded payload
async function parseSlackBody(req) {
  const bodyText = await req.text();
  const params = new URLSearchParams(bodyText);
  const data = {};
  for (const [key, value] of params.entries())data[key] = value;
  return data;
}
Deno.serve(async (req)=>{
  console.info("⚡ Slack /impersonate triggered");
  try {
    // Slack only sends POST requests
    if (req.method !== "POST") {
      return new Response("Only POST allowed", {
        status: 405
      });
    }
    const slackData = await parseSlackBody(req);
    const email = slackData.text?.trim();
    const channel = slackData.channel_name; // Slack field is channel_name
    console.log("Incoming Slack data:", slackData);
    // Only respond to a specific channel if needed
    if (channel && channel !== "shoreline-impersonate") {
      console.log("Ignored command from channel:", channel);
      return new Response(JSON.stringify({
        response_type: "in_",
        text: "⚠️ This command can only be used in #shoreline-impersonate."
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    if (!email) {
      return new Response(JSON.stringify({
        response_type: "in_channel",
        text: "⚠️ Please provide an email, e.g. `/impersonate user@example.com`"
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Supabase environment variables");
      return new Response(JSON.stringify({
        response_type: "in_channel",
        text: "❌ Server misconfigured. Missing Supabase credentials."
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    // Initialize Supabase admin client
    const supabaseAdmin = createClient(supabaseUrl, supabaseKey);
    const { data: list, error: listError } = await supabaseAdmin.auth.admin.listUsers();
    const user = list.users.find((u)=>u.email === email);
    if (listError || !user) {
      return new Response(JSON.stringify({
        response_type: "in_channel",
        text: "❌ Incorrect email address."
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    // Generate magic link
    const { data, error } = await supabaseAdmin.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: {
        redirectTo: "https://shoreline.islandshq.xyz/login"
      }
    });
    if (error) {
      console.error("❌ Error generating magic link:", error.message);
      return new Response(JSON.stringify({
        response_type: "ephemeral",
        text: `❌ Failed to generate magic link: ${error.message}`
      }), {
        status: 200,
        headers: {
          "Content-Type": "application/json"
        }
      });
    }
    console.log("✅ Magic link generated:", data?.properties?.action_link);
    // Respond publicly in Slack
    return new Response(JSON.stringify({
      response_type: "in_channel",
      text: `✅ Magic link for *${email}*:\n${data?.properties?.action_link}`
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("❌ Unexpected error:", err);
    return new Response(JSON.stringify({
      response_type: "ephemeral",
      text: "❌ An unexpected error occurred while generating the link."
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
});
