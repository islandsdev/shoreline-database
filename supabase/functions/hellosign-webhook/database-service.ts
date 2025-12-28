import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
export class DatabaseService {
  supabaseUrl;
  supabaseKey;
  supabase;
  constructor(supabaseUrl, supabaseKey){
    this.supabaseUrl = supabaseUrl;
    this.supabaseKey = supabaseKey;
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }
  async updateHelloSignDocumentStatus(fileId, status) {
    const { data, error } = await this.supabase.from("new_documents").update({
      status
    }).eq("file_id", fileId).select("*"); // return id and status for confirmation
    if (error) {
      throw new Error(error.message);
    }
    const { title, type, employee_id, company_id } = data?.[0];
    if (type === "EMPLOYEE_PLACEMENT_LETTER") await this.approveEmployee(employee_id);
    console.log("before this.saveDocument");
    await this.saveDocument(fileId, title, type, company_id);
    return data;
  }
  async saveDocument(fileId, title, type, company_id) {
    console.log("in saveDocument");
    const { data, error } = await this.supabase.from("companies").select("*").eq("id", company_id);
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
    const filePath = `${user_id}/${title}.pdf`;
    // 2. Upload to Supabase Storage
    const { error: uploadError } = await this.supabase.storage.from("documents").upload(filePath, fileBytes, {
      contentType: "application/pdf",
      upsert: true
    });
    if (uploadError) {
      console.log("uploadError");
      console.log(uploadError);
      return new Response("Supabase upload error: " + uploadError.message, {
        status: 500
      });
    }
    console.log("supabasestorage");
    let tag;
    if (type === 'EMPLOYEE_PLACEMENT_LETTER') tag = 'Employee';
    else tag = 'Contract';
    const x = {
      name: `${title}.pdf`,
      file_path: filePath,
      tag,
      user_id,
      bucket: 'documents'
    };
    const { data: insertData, error: insertError } = await this.supabase.from("documents").insert(x);
    if (insertError) {
      throw new Error(insertError.message);
    }
  }
  async approveEmployee(employeeId) {
    const { data, error } = await this.supabase.from("team_members").update({
      status: 'approved'
    }).eq("team_member_id", employeeId);
    if (error) {
      throw new Error(error.message);
    }
    try {
      const response = await fetch(`${this.supabaseUrl}/functions/v1/generate-payments`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.supabaseKey}`
        }
      });
      const result = await response.json();
      console.log("Edge function response:", result);
    } catch (err) {
      console.error("Error calling Edge Function:", err.message);
    }
    return data;
  }
}
