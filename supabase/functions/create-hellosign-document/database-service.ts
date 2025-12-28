import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
export class DatabaseService {
  supabase;
  constructor(supabaseUrl, supabaseKey){
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }
  async saveHelloSignDocument(signature_request, companyId, employeeId, type) {
    const { data, error } = await this.supabase.from("new_documents").insert({
      file_id: signature_request.signature_request_id,
      template_id: signature_request.template_ids?.[0],
      title: signature_request.title,
      type,
      status: signature_request.signatures[0].status_code,
      file_url: signature_request.signing_url,
      company_id: companyId,
      employee_id: employeeId || null
    }).select("id"); // explicitly request the id back
    if (error) {
      throw new Error(error.message);
    }
    return data;
  }
}
