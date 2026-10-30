view: headcount_month_end {
  sql_table_name: `payroll_gold.fct_headcount_month_end` ;;
  label: "Workforce"

  dimension: pk {
    primary_key: yes
    hidden: yes
    sql: CONCAT(${TABLE}.employee_id, '|', CAST(${TABLE}.month_end_date AS STRING)) ;;
  }

  dimension: employee_id   { hidden: yes sql: ${TABLE}.employee_id ;; }
  dimension: department_id { hidden: yes sql: ${TABLE}.department_id ;; }

  dimension_group: month_end {
    label: "Month End"
    description: "Last day of the month on which the employee was counted as active."
    type: time
    datatype: date
    convert_tz: no
    timeframes: [raw, date, month, fiscal_quarter, fiscal_year]
    sql: ${TABLE}.month_end_date ;;
  }

  dimension: fiscal_year {
    label: "Fiscal Year"
    group_label: "Fiscal Calendar"
    sql: ${TABLE}.fiscal_year ;;
  }

  dimension: fiscal_quarter {
    label: "Fiscal Quarter"
    group_label: "Fiscal Calendar"
    sql: ${TABLE}.fiscal_quarter ;;
  }

  measure: headcount {
    label: "Headcount"
    description: "Full-time and part-time employees active on the last day of the period."
    type: number
    # Count only the employees of the latest month-end in each result row.
    sql: (
      SELECT COUNT(DISTINCT x.employee_id)
      FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_end_date AS month_end_date, ${TABLE}.employee_id AS employee_id))) AS x
      WHERE x.month_end_date = (SELECT MAX(m) FROM UNNEST(ARRAY_AGG(${TABLE}.month_end_date)) AS m)
    ) ;;
    value_format_name: decimal_0
    drill_fields: [departments.department_name, employees.full_name, employees.job_title, employees.employment_type, employees.hire_date]
  }

  measure: average_month_end_headcount {
    label: "Average Month-End Headcount"
    type: number
    sql: SAFE_DIVIDE(COUNT(DISTINCT ${pk}), COUNT(DISTINCT ${TABLE}.month_end_date)) ;;
    value_format_name: decimal_1
  }
}
