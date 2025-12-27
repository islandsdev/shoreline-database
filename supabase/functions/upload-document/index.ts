import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const formData = await req.formData();
    const file = formData.get('file');
    const category = formData.get('category') || 'Employee' // Default to Employee if not specified
    ;
    if (!file) {
      return new Response(JSON.stringify({
        error: 'No file uploaded'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 400
      });
    }
    // Create Supabase client
    const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
    // Sanitize filename to remove non-ASCII characters
    const sanitizedFileName = file.name.replace(/[^\x00-\x7F]/g, '');
    const fileExt = sanitizedFileName.split('.').pop();
    const filePath = `${crypto.randomUUID()}.${fileExt}`;
    // Upload file to Storage
    const { data: storageData, error: uploadError } = await supabase.storage.from('documents').upload(filePath, file, {
      contentType: file.type,
      upsert: false
    });
    if (uploadError) {
      console.error('Upload error:', uploadError);
      return new Response(JSON.stringify({
        error: 'Failed to upload file',
        details: uploadError
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 500
      });
    }
    // Format file size
    const fileSizeInBytes = file.size;
    let fileSize;
    if (fileSizeInBytes < 1024) {
      fileSize = `${fileSizeInBytes} B`;
    } else if (fileSizeInBytes < 1024 * 1024) {
      fileSize = `${(fileSizeInBytes / 1024).toFixed(1)} KB`;
    } else {
      fileSize = `${(fileSizeInBytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    // Insert document metadata into documents table
    const { error: dbError } = await supabase.from('documents').insert({
      name: sanitizedFileName,
      size: fileSize,
      type: fileExt,
      category: category,
      file_path: filePath
    });
    if (dbError) {
      console.error('Database error:', dbError);
      return new Response(JSON.stringify({
        error: 'Failed to save document metadata',
        details: dbError
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 500
      });
    }
    return new Response(JSON.stringify({
      message: 'Document uploaded successfully',
      filePath,
      name: sanitizedFileName,
      size: fileSize,
      type: fileExt
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      error: 'An unexpected error occurred',
      details: error.message
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
