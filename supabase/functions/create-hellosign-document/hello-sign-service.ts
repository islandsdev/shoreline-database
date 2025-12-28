export class HelloSignService {
  apiKey;
  baseUrl = 'https://api.hellosign.com/v3';
  constructor(apiKey){
    this.apiKey = apiKey;
  }
  getAuthHeader() {
    // Basic Auth like curl -u "${API_KEY}:"
    const encoded = btoa(`${this.apiKey}:`);
    return `Basic ${encoded}`;
  }
  async sendDocumentWithTemplate(params) {
    const { templateId, signers, customFields = {}, subject = 'Please sign this document', message = 'Please review and sign the attached document.', IS_TEST_ENV = false } = params;
    // Validate required parameters
    if (!templateId) throw new Error('templateId is required');
    if (!signers) throw new Error('signers is required');
    if (!Array.isArray(signers) || signers.length === 0) {
      throw new Error("signers must be a non-empty array");
    }
    signers.forEach((signer, index)=>{
      if (!signer.email_address) {
        throw new Error(`email is required for signer at index ${index}`);
      }
      if (!signer.name) {
        throw new Error(`name is required for signer at index ${index}`);
      }
      if (!signer.role) {
        throw new Error(`role is required for signer at index ${index}`);
      }
    });
    const requestBody = {
      template_id: templateId,
      test_mode: IS_TEST_ENV,
      subject: subject,
      message: message,
      signers,
      custom_fields: this.formatCustomFields(customFields)
    };
    try {
      const response = await fetch(`${this.baseUrl}/signature_request/send_with_template`, {
        method: 'POST',
        headers: {
          'Authorization': this.getAuthHeader(),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });
      const responseData = await response.json();
      if (!response.ok) {
        throw new Error(`HelloSign API Error: ${responseData.error?.error_msg || 'Unknown error'}`);
      }
      console.log('✅ Document sent successfully:', {
        responseData
      });
      return responseData;
    } catch (error) {
      console.error('❌ Error sending document via HelloSign:', error.message);
      throw error;
    }
  }
  formatCustomFields(customFields) {
    return Object.entries(customFields).map(([name, value])=>({
        name: name,
        value: String(value)
      }));
  }
}
