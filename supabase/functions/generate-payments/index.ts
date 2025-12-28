// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ENV } from './envs.ts';
import { DatabaseService } from "./database-service.ts";
console.info('server started');
Deno.serve(async (req)=>{
  const body = await req.json().catch(()=>({}));
  const teamMemberId = body.team_member_id;
  const dbService = new DatabaseService(ENV.SUPABASE_URL, ENV.SUPABASE_SERVICE_ROLE_KEY);
  if (!teamMemberId) await dbService.generatePayrollSchedule();
  const missingPayments = await dbService.prepareMissingPayments(teamMemberId);
  try {
    await dbService.insertPayments(missingPayments);
    const returnString = missingPayments.length ? `Generated and inserted ${missingPayments.length} missing payments.` : `No missing payments found`;
    return new Response(returnString, {
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive'
      }
    });
  } catch (error) {
    console.error('Error inserting payments:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Failed to insert payments.'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive'
      }
    });
  }
});
