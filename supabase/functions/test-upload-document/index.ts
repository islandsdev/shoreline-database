// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
console.info('server started');
Deno.serve(async (req)=>{
  const supabase = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  const company_id = '58d3dd56-83db-4fdd-8f2c-6aac5895b47e';
  const fileId = '297b2bf7c29b3eeddf6575af38a57c542649ddf3';
  const title = 'test file';
  const { data, error } = await supabase.from("companies").select("*").eq("id", company_id);
  if (error) {
    throw new Error(error.message);
  }
  if (!data || data.length === 0) {
    throw new Error("Company not found");
  }
  const { user_id } = data[0];
  const helloSignRes = await fetch(`https://api.hellosign.com/v3/signature_request/files/${fileId}`, {
    method: "GET",
    headers: {
      Authorization: "Basic " + btoa(`${Deno.env.get("HELLOSIGN_API_KEY")}:`)
    }
  });
  if (!helloSignRes.ok) {
    const text = await helloSignRes.text();
    return new Response("Failed to fetch file: " + text, {
      status: 500
    });
  }
  const arrayBuffer = await helloSignRes.arrayBuffer();
  const fileBytes = new Uint8Array(arrayBuffer);
  const filePath = `b5025b75-6a5d-456a-99d9-0b7cd53c3a21/ Nadeem Ghaly - Employee Placement Letter.pdf`;
  // 2. Upload to Supabase Storage
  const { error: uploadError } = await supabase.storage.from("documents").upload(filePath, fileBytes, {
    contentType: "application/pdf",
    upsert: true
  });
  if (uploadError) {
    return new Response("Supabase upload error: " + uploadError.message, {
      status: 500
    });
  }
  const x = {
    name: title,
    file_path: filePath,
    tag: "Employee",
    user_id,
    bucket: 'documents'
  };
  const { data: insertData, error: insertError } = await supabase.from("documents").insert([
    x
  ]);
  if (insertError) {
    throw new Error(insertError.message);
  }
  return new Response(JSON.stringify(data), {
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive'
    }
  });
});
