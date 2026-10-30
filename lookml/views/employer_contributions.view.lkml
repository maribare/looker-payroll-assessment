view: employer_contributions {
  sql_table_name: `payroll_gold.fct_employer_contributions` ;;
  label: "Employer Contributions"

  dimension: contribution_id {
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.contribution_id ;;
  }

  dimension: pay_run_id  { hidden: yes sql: ${TABLE}.pay_run_id ;; }
  dimension: employee_id { hidden: yes sql: ${TABLE}.employee_id ;; }

  dimension: contribution_type {
    label: "Contribution Type"
    description: "FICA, HEALTH_INSURANCE or RETIREMENT_MATCH."
    sql: ${TABLE}.contribution_type ;;
  }

  measure: employer_cost {
    label: "Employer Cost"
    description: "Employer contributions for the pay runs in the period."
    type: sum
    sql: ${TABLE}.amount_usd ;;
    value_format_name: usd_0
  }
}
