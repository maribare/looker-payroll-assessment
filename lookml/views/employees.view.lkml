view: employees {
  sql_table_name: `payroll_gold.dim_employee` ;;
  label: "Employee"

  dimension: employee_id {
    primary_key: yes
    label: "Employee ID"
    sql: ${TABLE}.employee_id ;;
  }

  dimension: full_name {
    label: "Employee Name"
    sql: ${TABLE}.full_name ;;
  }

  dimension: email {
    label: "E-mail"
    sql: ${TABLE}.email ;;
    required_access_grants: [can_see_individual_pay]
  }

  dimension: job_title {
    label: "Job Title"
    sql: ${TABLE}.job_title ;;
  }

  dimension: employment_type {
    label: "Employment Type"
    description: "FULL_TIME, PART_TIME or CONTRACTOR. Contractors are not counted in headcount."
    sql: ${TABLE}.employment_type ;;
  }

  dimension: flsa_status {
    label: "FLSA Status"
    description: "EXEMPT (salaried, no overtime) or NON_EXEMPT (eligible for overtime)."
    sql: ${TABLE}.flsa_status ;;
  }

  dimension: location_state {
    label: "Work State"
    sql: ${TABLE}.location_state ;;
  }

  dimension_group: hire {
    label: "Hire"
    type: time
    datatype: date
    convert_tz: no
    timeframes: [date, month, fiscal_quarter, fiscal_year]
    sql: ${TABLE}.hire_date ;;
  }

  dimension_group: termination {
    label: "Termination"
    type: time
    datatype: date
    convert_tz: no
    timeframes: [date, month, fiscal_quarter, fiscal_year]
    sql: ${TABLE}.termination_date ;;
  }

  dimension: termination_reason {
    label: "Termination Reason"
    description: "VOLUNTARY, INVOLUNTARY or RETIREMENT."
    sql: ${TABLE}.termination_reason ;;
  }

  dimension: current_department_id {
    hidden: yes
    sql: ${TABLE}.current_department_id ;;
  }

  # ---------------------------------------------------------- confidential: HR and Finance only
  dimension: annual_salary_usd {
    label: "Annual Salary"
    group_label: "Pay (HR & Finance only)"
    type: number
    sql: ${TABLE}.annual_salary_usd ;;
    value_format_name: usd_0
    required_access_grants: [can_see_individual_pay]
  }

  dimension: hourly_rate_usd {
    label: "Hourly Rate"
    group_label: "Pay (HR & Finance only)"
    type: number
    sql: ${TABLE}.hourly_rate_usd ;;
    value_format_name: usd
    required_access_grants: [can_see_individual_pay]
  }

  dimension: annualized_base_pay_usd {
    label: "Annualized Base Pay (FTE)"
    group_label: "Pay (HR & Finance only)"
    description: "Annual salary, or hourly rate x 2,080 hours."
    type: number
    sql: ${TABLE}.annualized_base_pay_usd ;;
    value_format_name: usd_0
    required_access_grants: [can_see_individual_pay]
  }

  measure: average_annualized_base_pay {
    label: "Average Annualized Base Pay"
    group_label: "Pay (HR & Finance only)"
    type: average
    sql: ${annualized_base_pay_usd} ;;
    value_format_name: usd_0
    required_access_grants: [can_see_individual_pay]
  }

  measure: employee_count {
    label: "Number of Employees"
    type: count_distinct
    sql: ${employee_id} ;;
    drill_fields: [employee_id, full_name, job_title, employment_type, hire_date]
  }
}
