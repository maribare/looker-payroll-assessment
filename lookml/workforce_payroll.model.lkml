connection: "payroll_bigquery"
label: "Workforce & Payroll"

include: "/lookml/views/*.view.lkml"
include: "/lookml/dashboards/*.dashboard.lookml"

# Fiscal year runs July - June and is named after the year in which it ends
# (FY2026 = July 2025 - June 2026). A NEGATIVE offset tells Looker the fiscal
# year starts in the previous calendar year, so July 2025 falls in FY2026.
fiscal_month_offset: -6
week_start_day: monday

# ---------------------------------------------------------------------------
# Caching: Dataform writes a row to dataform_run_log at the end of each run,
# only after the gold tables are rebuilt and the assertions pass. Looker polls
# this cheap query; when the value changes, the cache is dropped and PDTs /
# aggregate tables are rebuilt. max_cache_age is a safety net.
# ---------------------------------------------------------------------------
datagroup: payroll_gold_refresh {
  label: "Payroll gold layer refreshed"
  description: "Triggers when Dataform finishes a successful run."
  sql_trigger: SELECT MAX(finished_at) FROM `payroll_gold.dataform_run_log` ;;
  max_cache_age: "24 hours"
}

persist_with: payroll_gold_refresh

# ---------------------------------------------------------------------------
# Security
#   payroll_access_role     : hr | finance | leadership | manager
#   allowed_department_ids  : "%" (all) for hr, finance and leadership;
#                             the manager's department id(s), e.g. "D04", for managers
# ---------------------------------------------------------------------------
access_grant: can_see_individual_pay {
  user_attribute: payroll_access_role
  allowed_values: ["hr", "finance"]
}

# ---------------------------------------------------------------------------
# 1. Main explore for the executive dashboard.
#    Built on the gold table at department x month grain. Every metric
#    (payroll, employer cost, budget, headcount, exits) is already at the same
#    grain, so there is no fan-out: the only join is to a dimension
#    (many_to_one), and totals are right at any level of detail.
# ---------------------------------------------------------------------------
explore: department_monthly {
  label: "Payroll, Budget & Workforce (monthly)"
  description: "Start here. Gross payroll, employer cost, overtime, headcount, turnover and budget by department and month."

  access_filter: {
    field: department_monthly.department_id
    user_attribute: allowed_department_ids
  }

  join: departments {
    type: left_outer
    relationship: many_to_one
    sql_on: ${department_monthly.department_id} = ${departments.department_id} ;;
  }
}

# ---------------------------------------------------------------------------
# 2. Detail explore: one row per valid earning line.
#    - departments: many_to_one on the cost center charged on the line.
#    - employer_contributions: many_to_many on (pay run, employee). One employee
#      has several lines AND several contributions in a run. Both views declare
#      a primary key, so Looker uses symmetric aggregates and neither total is
#      inflated.
#    - budget: many_to_one on (department, month). Primary key on the budget
#      view keeps budget totals right through symmetric aggregates.
#    - employees: per-person data. The whole join requires HR/Finance so that
#      nobody else can break payroll down by person.
# ---------------------------------------------------------------------------
explore: payroll_lines {
  label: "Payroll Lines (detail)"
  description: "Line-level payroll for analysis and drill-down. For budget and headcount questions use the monthly explore."

  access_filter: {
    field: payroll_lines.department_id
    user_attribute: allowed_department_ids
  }

  join: departments {
    type: left_outer
    relationship: many_to_one
    sql_on: ${payroll_lines.department_id} = ${departments.department_id} ;;
  }

  join: employer_contributions {
    type: left_outer
    relationship: many_to_many
    sql_on: ${payroll_lines.pay_run_id} = ${employer_contributions.pay_run_id}
      AND ${payroll_lines.employee_id} = ${employer_contributions.employee_id} ;;
  }

  join: budget {
    type: left_outer
    relationship: many_to_one
    sql_on: ${payroll_lines.department_id} = ${budget.department_id}
      AND ${payroll_lines.pay_month_start} = ${budget.month_start_date} ;;
  }

  join: employees {
    type: left_outer
    relationship: many_to_one
    sql_on: ${payroll_lines.employee_id} = ${employees.employee_id} ;;
    required_access_grants: [can_see_individual_pay]
  }

  # Aggregate awareness: monthly queries by department are answered from this
  # small table instead of scanning every line. Rebuilt with the datagroup.
  aggregate_table: monthly_by_department {
    query: {
      dimensions: [payroll_lines.pay_month, payroll_lines.fiscal_year, payroll_lines.fiscal_quarter, departments.department_name, departments.division]
      measures: [payroll_lines.gross_payroll, payroll_lines.overtime_pay, payroll_lines.total_hours, payroll_lines.overtime_hours]
    }
    materialization: {
      datagroup_trigger: payroll_gold_refresh
    }
  }
}

# ---------------------------------------------------------------------------
# 3. Workforce explore: one row per employee active at each month end.
#    Managers can list the people in their own department (names, titles,
#    hire dates). Pay fields in the employees view carry their own access grant.
# ---------------------------------------------------------------------------
explore: headcount_month_end {
  label: "Workforce (month-end headcount)"
  description: "Who was active at the end of each month, with the department they belonged to at that date."

  access_filter: {
    field: headcount_month_end.department_id
    user_attribute: allowed_department_ids
  }

  join: departments {
    type: left_outer
    relationship: many_to_one
    sql_on: ${headcount_month_end.department_id} = ${departments.department_id} ;;
  }

  join: employees {
    type: left_outer
    relationship: many_to_one
    sql_on: ${headcount_month_end.employee_id} = ${employees.employee_id} ;;
  }
}

# ---------------------------------------------------------------------------
# 4. Average pay by job title, safe for leadership.
#    Pre-aggregated in a PDT: no row for a single person exists, titles with
#    fewer than 5 people are pooled, and there is no department dimension to
#    slice groups smaller.
# ---------------------------------------------------------------------------
explore: salary_by_job_title {
  label: "Average Pay by Job Title"
  description: "Average annual base pay by job title for current employees. Groups under 5 people are pooled to protect individual pay."
}
