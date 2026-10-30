view: payroll_lines {
  sql_table_name: `payroll_gold.fct_payroll_lines` ;;
  label: "Payroll"

  dimension: payroll_line_id {
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.payroll_line_id ;;
  }

  dimension: pay_run_id {
    label: "Pay Run"
    description: "Biweekly pay run identifier (PR-YYYYMMDD)."
    sql: ${TABLE}.pay_run_id ;;
  }

  dimension: employee_id {
    hidden: yes
    sql: ${TABLE}.employee_id ;;
  }

  dimension: department_id {
    hidden: yes
    sql: ${TABLE}.department_id ;;
  }

  dimension_group: pay {
    label: "Pay"
    description: "Date the pay run was paid. Gross payroll is assigned to the month of this date."
    type: time
    datatype: date
    convert_tz: no
    timeframes: [raw, date, week, month, quarter, year, fiscal_quarter, fiscal_quarter_of_year, fiscal_year, fiscal_month_num]
    sql: ${TABLE}.pay_date ;;
  }

  dimension: pay_month_start {
    hidden: yes
    type: date
    convert_tz: no
    sql: ${TABLE}.pay_month ;;
  }

  dimension: fiscal_year {
    label: "Fiscal Year"
    group_label: "Fiscal Calendar"
    description: "July to June, named after the year it ends. FY2026 = July 2025 to June 2026."
    sql: ${TABLE}.fiscal_year ;;
  }

  dimension: fiscal_quarter {
    label: "Fiscal Quarter"
    group_label: "Fiscal Calendar"
    description: "Q1 = July-September ... Q4 = April-June. Example: FY2027-Q1."
    sql: ${TABLE}.fiscal_quarter ;;
  }

  dimension: earning_type {
    label: "Earning Type"
    description: "REGULAR, OVERTIME, PTO (paid time off) or BONUS."
    sql: ${TABLE}.earning_type ;;
  }

  dimension: hours       { hidden: yes type: number sql: ${TABLE}.hours ;; }
  dimension: amount_usd  { hidden: yes type: number sql: ${TABLE}.amount_usd ;; }

  measure: gross_payroll {
    label: "Gross Payroll"
    description: "All valid earnings paid in the period. Excludes voided lines, duplicates and test accounts."
    type: sum
    sql: ${amount_usd} ;;
    value_format_name: usd_0
    drill_fields: [drill_detail*]
  }

  measure: overtime_pay {
    label: "Overtime Pay"
    type: sum
    sql: ${TABLE}.overtime_amount_usd ;;
    value_format_name: usd_0
    drill_fields: [drill_detail*]
  }

  measure: overtime_pct {
    label: "Overtime %"
    description: "Overtime pay / gross payroll."
    type: number
    sql: SAFE_DIVIDE(${overtime_pay}, ${gross_payroll}) ;;
    value_format_name: percent_1
    drill_fields: [drill_detail*]
  }

  measure: total_hours {
    label: "Paid Hours"
    type: sum
    sql: ${hours} ;;
    value_format_name: decimal_0
  }

  measure: overtime_hours {
    label: "Overtime Hours"
    type: sum
    sql: ${TABLE}.overtime_hours ;;
    value_format_name: decimal_0
  }

  measure: fully_loaded_cost {
    label: "Fully Loaded Payroll Cost"
    description: "Gross payroll + employer cost. Employer cost follows the lines kept by your filters (filtering on earning type keeps the full contribution of the matching employees)."
    type: number
    sql: ${gross_payroll} + ${employer_contributions.employer_cost} ;;
    value_format_name: usd_0
  }

  # Drill stays at department / month / earning type: no individual pay for non-HR users.
  set: drill_detail {
    fields: [departments.division, departments.department_name, pay_month, earning_type, gross_payroll, total_hours]
  }
}
