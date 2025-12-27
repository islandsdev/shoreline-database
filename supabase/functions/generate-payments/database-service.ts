import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
export class DatabaseService {
  supabase;
  constructor(supabaseUrl, supabaseKey){
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }
  async generatePayrollSchedule() {
    await this._generateSchedule("Bi-Weekly");
    await this._generateSchedule("Monthly");
  }
  async insertPayments(missingPayments) {
    if (!missingPayments?.length) return;
    const { data, error } = await this.supabase.from("payments").insert(missingPayments);
    if (error) {
      console.error("Error inserting payments:", error);
      throw error;
    }
    return data;
  }
  async prepareMissingPayments(teamMemberId) {
    let query = this.supabase.from("team_members").select("*").eq("status", "approved");
    if (teamMemberId) {
      query = query.eq("team_member_id", teamMemberId);
    }
    const { data: employees, error } = await query;
    if (!employees || !employees.length) {
      console.log("No Employees found");
      return [];
    }
    const todayString = new Date().toISOString().split("T")[0];
    const { data: payrollSchedules } = await this.supabase.from("payroll_schedules").select("*").gte("start_date", todayString);
    const payrollScheduleIds = payrollSchedules.map((schedule)=>schedule.id);
    const { data: existingPayments } = await this.supabase.from("payments").select("*").in("payroll_schedule_id", payrollScheduleIds);
    const paymentsToInsert = [];
    for (const employee of employees){
      const { team_member_id: id, salary, payroll_schedule } = employee;
      const employeePayments = existingPayments.filter((payment)=>payment.team_member_id === id);
      const filteredPayrolls = payrollSchedules.filter((schedule)=>new Date(schedule.start_date) >= new Date(employee.commencement_date));
      const missedPayrolls = filteredPayrolls.filter((schedule)=>!employeePayments.some((payment)=>payment.payroll_schedule_id === schedule.id));
      const periodsPerYear = payroll_schedule === "Bi-Weekly" ? 26 : 12;
      const amount = Math.round(salary / periodsPerYear * 100) / 100;
      for (const missedPayroll of missedPayrolls){
        paymentsToInsert.push({
          team_member_id: id,
          payroll_schedule_id: missedPayroll.id,
          gross_salary: amount
        });
      }
    }
    console.log(`✅ Generated ${paymentsToInsert.length} missing payments.`);
    return paymentsToInsert;
  }
  async _generateSchedule(type) {
    const today = new Date().toISOString().split("T")[0];
    const { data: latestSchedule, error } = await this.supabase.from("payroll_schedules").select("*").eq("type", type).gte("start_date", today).order("end_date", {
      ascending: false
    }).limit(1);
    if (error) throw error;
    const last = latestSchedule?.[0];
    if (!last) {
      console.log(`No ${type} schedule found.`);
      return;
    }
    const newSchedules = this._createSchedules(last, type);
    if (newSchedules.length === 0) {
      console.log(`No new ${type} schedules needed.`);
      return;
    }
    const { error: insertError } = await this.supabase.from("payroll_schedules").insert(newSchedules);
    if (insertError) throw insertError;
    console.log(`✅ Added ${newSchedules.length} new ${type} schedules.`);
  }
  _createSchedules(last, type) {
    let nextStart = new Date(last.end_date);
    const sixMonthsLater = new Date();
    sixMonthsLater.setMonth(sixMonthsLater.getMonth() + 12);
    const newSchedules = [];
    const now = new Date();
    while(nextStart < sixMonthsLater){
      nextStart.setDate(nextStart.getDate() + 1);
      const nextEnd = new Date(nextStart);
      if (type === "Bi-Weekly") {
        nextEnd.setDate(nextEnd.getDate() + 13);
      } else {
        nextEnd.setMonth(nextEnd.getMonth() + 1);
        nextEnd.setDate(nextEnd.getDate() - 1);
      }
      if (nextStart > now) {
        newSchedules.push({
          start_date: nextStart.toISOString().split("T")[0],
          end_date: nextEnd.toISOString().split("T")[0],
          type
        });
      }
      nextStart = new Date(nextEnd);
    }
    return newSchedules;
  }
}
