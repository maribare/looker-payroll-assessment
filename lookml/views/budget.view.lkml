view: budget {
  # Budget columns live in the monthly gold table (one row per department and month).
  sql_table_name: `payroll_gold.agg_department_monthly` ;;
  label: "Budget"

  dimension: pk {
    primary_key: yes
    hidden: yes
    sql: CONCAT(${TABLE}.department_id, '|', CAST(${TABLE}.month_start_date AS STRING)) ;;
  }

  dimension: department_id { hidden: yes sql: ${TABLE}.department_id ;; }

  dimension: month_start_date {
    hidden: yes
    type: date
    convert_tz: no
    sql: ${TABLE}.month_start_date ;;
  }

  measure: budgeted_gross_payroll {
    label: "Budgeted Gross Payroll"
    description: "Monthly budget. Only meaningful by month or a longer period."
    type: sum
    sql: ${TABLE}.budgeted_gross_payroll_usd ;;
    value_format_name: usd_0
  }

  measure: budget_variance_pct {
    label: "Budget Variance %"
    description: "(Actual gross payroll / budgeted gross payroll) - 1. Positive = over budget."
    type: number
    sql: SAFE_DIVIDE(${payroll_lines.gross_payroll}, ${budgeted_gross_payroll}) - 1 ;;
    value_format_name: percent_1
  }
}
