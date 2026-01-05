function roundUpToTwoDecimals(value) {
  return Math.round(value * 100) / 100;
}
function formatDateRange(startDateStr, endDateStr) {
  const startDate = new Date(startDateStr);
  const endDate = new Date(endDateStr);
  const startStr = startDate.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
  });
  const endStr = endDate.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
  });
  return `${startStr} - ${endStr}`;
}
function calculateCPP(totalAmount, hasSalary) {
  const periods = 26;
  const CPP_RATE = 5.95 / 100;
  const CPP_BASIC_EXEMPTION_ANNUAL = 3500;
  const CPP_MAX_EARNINGS_ANNUAL = 68500;
  const minSalary = hasSalary
    ? Math.max(CPP_MAX_EARNINGS_ANNUAL / periods, totalAmount)
    : totalAmount;
  const employerCpp =
    (minSalary - CPP_BASIC_EXEMPTION_ANNUAL / periods) * CPP_RATE;
  return roundUpToTwoDecimals(employerCpp);
}
function calculateEEI(totalAmount, hasSalary) {
  const periods = 26;
  const EI_EMPLOYER_RATE = 2.296 / 100;
  const EI_MIN_INSURABLE_EARNINGS_ANNUAL = 63200;
  const insurableEarnings = hasSalary
    ? Math.max(EI_MIN_INSURABLE_EARNINGS_ANNUAL / periods, totalAmount)
    : totalAmount;
  const employerEi = insurableEarnings * EI_EMPLOYER_RATE;
  return roundUpToTwoDecimals(employerEi);
}
function getEmployeeInvoiceItems(employees, rate) {
  const items = [];
  for (const employee of employees) {
    const hasSalary = employee.gross_salary ? true : false;
    // Gross salary item
    employee.gross_salary
      ? items.push({
          description: `${employee.employee_name}, GS (${employee.gross_salary_date_range}), CAD ${employee.gross_salary} @ ${rate}`,
          amount: roundUpToTwoDecimals(employee.gross_salary * rate),
        })
      : null;
    // ECPP item
    const ecpp = calculateCPP(employee.total_amount, hasSalary);
    employee.total_amount
      ? items.push({
          description: `${employee.employee_name}, ECPP (${employee.gross_salary_date_range}), CAD ${ecpp} @ ${rate}`,
          amount: roundUpToTwoDecimals(ecpp * rate),
        })
      : null;
    // EEI item
    const eei = calculateEEI(employee.total_amount, hasSalary);
    employee.total_amount
      ? items.push({
          description: `${employee.employee_name}, EEI (${employee.gross_salary_date_range}), CAD ${eei} @ ${rate}`,
          amount: roundUpToTwoDecimals(eei * rate),
        })
      : null;
    // RRSP item
    employee.rrsp
      ? items.push({
          description: `${employee.employee_name}, RRSP (${employee.gross_salary_date_range}), CAD ${employee.rrsp} @ ${rate}`,
          amount: roundUpToTwoDecimals(employee.rrsp * rate),
        })
      : null;
    // One-time payment items
    for (const oneTimePayment of employee.one_time_payments) {
      if (oneTimePayment.amount > 0) {
        const paymentTypeString = oneTimePayment.payment_type
          .slice(0, 2)
          .toUpperCase();
        items.push({
          description: `${employee.employee_name}, ${paymentTypeString} (${oneTimePayment.date_range}), CAD ${oneTimePayment.amount} @ ${rate}`,
          amount: roundUpToTwoDecimals(oneTimePayment.amount * rate),
        });
      }
    }
  }
  return items;
}
function getEmployeeId(employee) {
  return (
    employee.team_member_id || `${employee.first_name}_${employee.last_name}`
  );
}

function getPaymentMethodByEmploymentType(employmentType) {
  if (employmentType === "Employee") {
    return "Stripe";
  } else if (employmentType === "Contractor") {
    return "Wise";
  }
  // Default to Stripe if unknown
  return "Stripe";
}

function getCompanyPaymentKey(companyId, paymentMethod) {
  return `${companyId}_${paymentMethod}`;
}
function createCompanyData(company, paymentMethod) {
  return {
    company_id: company.id,
    company_name: company.legal_name,
    company_stripe_id: company.customer_stripe_id,
    payment_method: paymentMethod,
    billing_email: company.billing_email,
    employees: new Map(),
    paystubIds: [],
    oneTimePaymentIds: [],
  };
}
function createEmployeeData(employee) {
  return {
    employee_id: getEmployeeId(employee),
    employee_name: `${employee.first_name} ${employee.last_name}`,
    gross_salary: 0,
    rrsp: 0,
    gross_salary_date_range: "",
    one_time_payments: [],
  };
}
function getOrCreateCompany(companiesMap, company, paymentMethod) {
  const key = getCompanyPaymentKey(company.id, paymentMethod);
  if (!companiesMap.has(key)) {
    companiesMap.set(key, createCompanyData(company, paymentMethod));
  }
  return companiesMap.get(key);
}
function getOrCreateEmployee(companyData, employee) {
  const employeeId = getEmployeeId(employee);
  if (!companyData.employees.has(employeeId)) {
    companyData.employees.set(employeeId, createEmployeeData(employee));
  }
  return companyData.employees.get(employeeId);
}
function processPaystubs(companiesMap, paystubs, topups) {
  for (const paystub of paystubs) {
    const employee = paystub.employee;
    const company = employee.company;
    // Determine payment method based on employment type
    const paymentMethod = getPaymentMethodByEmploymentType(
      employee.employment_type
    );
    const companyData = getOrCreateCompany(
      companiesMap,
      company,
      paymentMethod
    );
    const employeeData = getOrCreateEmployee(companyData, employee);
    companyData.paystubIds.push(paystub.id);
    employeeData.gross_salary += paystub.gross_salary;
    if (
      employee.rrsp_plan &&
      topups.some((topup) => topup.team_member_id === employee.team_member_id)
    ) {
      if (employee.rrsp_plan.type == "percentage")
        employeeData.rrsp = roundUpToTwoDecimals(
          employeeData.gross_salary * (employee.rrsp_plan.amount / 100)
        );
      else employeeData.rrsp = employee.rrsp_plan.amount;
    }
    employeeData.gross_salary_date_range = formatDateRange(
      paystub.payroll_schedule.start_date,
      paystub.payroll_schedule.end_date
    );
  }
}
function processOneTimePayments(companiesMap, oneTimePayments) {
  for (const oneTimePayment of oneTimePayments) {
    const employee = oneTimePayment.employee;
    const company = employee.company;
    // Determine payment method based on employment type
    const paymentMethod = getPaymentMethodByEmploymentType(
      employee.employment_type
    );
    const companyData = getOrCreateCompany(
      companiesMap,
      company,
      paymentMethod
    );
    const employeeData = getOrCreateEmployee(companyData, employee);
    companyData.oneTimePaymentIds.push(oneTimePayment.id);
    employeeData.one_time_payments.push({
      payment_type: oneTimePayment.payment_type,
      amount: roundUpToTwoDecimals(oneTimePayment.amount),
      date_range: formatDateRange(
        oneTimePayment.payroll_schedule.start_date,
        oneTimePayment.payroll_schedule.end_date
      ),
    });
    if (!employeeData.gross_salary_date_range) {
      employeeData.gross_salary_date_range = formatDateRange(
        oneTimePayment.payroll_schedule.start_date,
        oneTimePayment.payroll_schedule.end_date
      );
    }
  }
}
function convertEmployeeData(employeeData) {
  const grossSalary = roundUpToTwoDecimals(employeeData.gross_salary);
  const rrsp = roundUpToTwoDecimals(employeeData.rrsp);
  const oneTimePaymentsTotal = employeeData.one_time_payments.reduce(
    (sum, payment) => sum + payment.amount,
    0
  );
  const totalAmount = roundUpToTwoDecimals(
    grossSalary + oneTimePaymentsTotal + rrsp
  );
  return {
    employee_id: employeeData.employee_id,
    employee_name: employeeData.employee_name,
    total_amount: totalAmount,
    gross_salary: grossSalary,
    rrsp: rrsp,
    gross_salary_date_range: employeeData.gross_salary_date_range,
    one_time_payments: employeeData.one_time_payments,
  };
}
function convertToResultFormat(companiesMap, rate) {
  const result = [];
  for (const companyData of companiesMap.values()) {
    const employees = Array.from(companyData.employees.values()).map(
      (employeeData) => convertEmployeeData(employeeData)
    );
    result.push({
      company_id: companyData.company_id,
      company_name: companyData.company_name,
      company_stripe_id: companyData.company_stripe_id,
      payment_method: companyData.payment_method,
      billing_email: companyData.billing_email,
      employees: employees,
      paystubIds: companyData.paystubIds,
      oneTimePaymentIds: companyData.oneTimePaymentIds,
    });
  }
  return result;
}
export function groupByCompany(paystubs, oneTimePayments, rate, topups) {
  const companiesMap = new Map();
  processPaystubs(companiesMap, paystubs, topups);
  processOneTimePayments(companiesMap, oneTimePayments);
  const result = convertToResultFormat(companiesMap, rate);
  return result.map((company) => ({
    company_id: company.company_id,
    company_name: company.company_name,
    company_stripe_id: company.company_stripe_id || null,
    payment_method: company.payment_method,
    billing_email: company.billing_email || null,
    invoices: getEmployeeInvoiceItems(company.employees, rate),
    paystubIds: company.paystubIds,
    oneTimePaymentIds: company.oneTimePaymentIds,
  }));
}
