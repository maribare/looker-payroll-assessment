view: department_monthly {
  sql_table_name: `payroll_gold.agg_department_monthly` ;;
  label: "Payroll & Workforce"

  # ------------------------------------------------------------------ keys
  dimension: pk {
    primary_key: yes
    hidden: yes
    sql: CONCAT(${TABLE}.department_id, '|', CAST(${TABLE}.month_start_date AS STRING)) ;;
  }

  dimension: department_id {
    hidden: yes
    sql: ${TABLE}.department_id ;;
  }

  # ------------------------------------------------------------------ time
  dimension_group: period {
    label: "Payroll"
    description: "Calendar month. Payroll is assigned to the month of the pay date; headcount is taken on the last day of the month."
    type: time
    datatype: date
    convert_tz: no
    timeframes: [raw, month, month_name, quarter, year, fiscal_quarter, fiscal_quarter_of_year, fiscal_year, fiscal_month_num]
    sql: ${TABLE}.month_start_date ;;
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
    description: "Q1 = July-September, Q2 = October-December, Q3 = January-March, Q4 = April-June. Example: FY2027-Q1."
    sql: ${TABLE}.fiscal_quarter ;;
  }

  dimension: fiscal_period {
    label: "Fiscal Month Number"
    group_label: "Fiscal Calendar"
    description: "1 = July ... 12 = June."
    type: number
    sql: ${TABLE}.fiscal_period ;;
  }

  # ------------------------------------------------------------------ hidden raw columns
  dimension: headcount_raw              { hidden: yes type: number sql: ${TABLE}.headcount ;; }
  dimension: budgeted_headcount_raw     { hidden: yes type: number sql: ${TABLE}.budgeted_headcount ;; }
  dimension: prior_year_headcount_raw   { hidden: yes type: number sql: ${TABLE}.prior_year_headcount ;; }

  # ================================================================== payroll vs budget
  measure: gross_payroll {
    label: "Gross Payroll"
    group_label: "Payroll Cost"
    description: "All valid earnings (regular, overtime, PTO, bonus) paid in the period. Excludes voided lines, duplicates and test accounts."
    type: sum
    sql: ${TABLE}.gross_payroll_usd ;;
    value_format_name: usd_0
    drill_fields: [drill_department_month*]
  }

  measure: budgeted_gross_payroll {
    label: "Budgeted Gross Payroll"
    group_label: "Budget"
    description: "Gross payroll budget for the period."
    type: sum
    sql: ${TABLE}.budgeted_gross_payroll_usd ;;
    value_format_name: usd_0
    drill_fields: [drill_department_month*]
  }

  measure: budget_variance_pct {
    label: "Budget Variance %"
    group_label: "Budget"
    description: "(Actual gross payroll / budgeted gross payroll) - 1. Positive = over budget."
    type: number
    sql: SAFE_DIVIDE(${gross_payroll}, ${budgeted_gross_payroll}) - 1 ;;
    value_format_name: percent_1
    drill_fields: [drill_department_month*]
    # Liquid: color and words, so the meaning does not depend on color alone.
    html:
      {% if value > 0.02 %}
        <span style="color:#d03b3b;font-weight:600;">&#9650; {{ rendered_value }} over budget</span>
      {% elsif value < -0.02 %}
        <span style="color:#006300;font-weight:600;">&#9660; {{ rendered_value }} under budget</span>
      {% else %}
        <span style="color:#52514e;font-weight:600;">&#9679; {{ rendered_value }} on budget</span>
      {% endif %} ;;
  }

  # Custom visual element: a bullet bar (actual vs budget) inside a table cell.
  measure: budget_bullet {
    label: "Actual vs Budget"
    group_label: "Budget"
    description: "Share of the budget used. The dark line marks 100% of budget."
    type: number
    sql: SAFE_DIVIDE(${gross_payroll}, ${budgeted_gross_payroll}) ;;
    value_format_name: percent_0
    html:
      {% if value > 1.3 %}{% assign width = 100 %}{% else %}{% assign width = value | times: 76.92 %}{% endif %}
      {% if value > 1.02 %}{% assign color = '#d03b3b' %}{% elsif value < 0.98 %}{% assign color = '#0ca30c' %}{% else %}{% assign color = '#898781' %}{% endif %}
      <div style="position:relative;height:18px;min-width:160px;background:#f0efec;border-radius:3px;">
        <div style="position:absolute;left:0;top:4px;height:10px;width:{{ width }}%;background:{{ color }};border-radius:2px;"></div>
        <div style="position:absolute;left:76.92%;top:0;height:18px;width:2px;background:#0b0b0b;"></div>
      </div>
      <span style="font-size:11px;color:#52514e;">{{ rendered_value }} of budget</span> ;;
  }

  # ================================================================== employer & fully loaded cost
  measure: employer_cost {
    label: "Employer Cost"
    group_label: "Payroll Cost"
    description: "Employer contributions (FICA, health insurance, retirement match) for the pay runs paid in the period."
    type: sum
    sql: ${TABLE}.employer_cost_usd ;;
    value_format_name: usd_0
    drill_fields: [drill_department_month*]
  }

  measure: fully_loaded_cost {
    label: "Fully Loaded Payroll Cost"
    group_label: "Payroll Cost"
    description: "Gross payroll + employer cost."
    type: number
    sql: ${gross_payroll} + ${employer_cost} ;;
    value_format_name: usd_0
    drill_fields: [drill_department_month*]
  }

  # ================================================================== overtime
  measure: overtime_pay {
    label: "Overtime Pay"
    group_label: "Overtime"
    description: "Earnings of type OVERTIME."
    type: sum
    sql: ${TABLE}.overtime_usd ;;
    value_format_name: usd_0
    drill_fields: [drill_department_month*]
  }

  measure: overtime_hours {
    label: "Overtime Hours"
    group_label: "Overtime"
    type: sum
    sql: ${TABLE}.overtime_hours ;;
    value_format_name: decimal_0
  }

  measure: overtime_pct {
    label: "Overtime %"
    group_label: "Overtime"
    description: "Overtime pay / gross payroll."
    type: number
    sql: SAFE_DIVIDE(${overtime_pay}, ${gross_payroll}) ;;
    value_format_name: percent_1
    drill_fields: [drill_department_month*]
  }

  # ================================================================== headcount & turnover
  measure: headcount {
    label: "Headcount"
    group_label: "Workforce"
    description: "Full-time and part-time employees active on the LAST day of the period (for a quarter: the last month-end of the quarter)."
    type: number
    # Headcount is a snapshot and cannot be summed across months. Collect the
    # (month, headcount) pairs of each result row and add up only the latest month.
    sql: (
      SELECT SUM(x.headcount)
      FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS month_start_date, ${TABLE}.headcount AS headcount))) AS x
      WHERE x.month_start_date = (SELECT MAX(m) FROM UNNEST(ARRAY_AGG(${TABLE}.month_start_date)) AS m)
    ) ;;
    value_format_name: decimal_0
    drill_fields: [drill_workforce*]
  }

  measure: budgeted_headcount {
    label: "Budgeted Headcount"
    group_label: "Budget"
    description: "Budgeted headcount for the last month of the period."
    type: number
    sql: (
      SELECT SUM(x.budgeted_headcount)
      FROM UNNEST(ARRAY_AGG(STRUCT(${TABLE}.month_start_date AS month_start_date, ${TABLE}.budgeted_headcount AS budgeted_headcount))) AS x
      WHERE x.month_start_date = (SELECT MAX(m) FROM UNNEST(ARRAY_AGG(${TABLE}.month_start_date)) AS m)
    ) ;;
    value_format_name: decimal_0
  }

  measure: average_month_end_headcount {
    label: "Average Month-End Headcount"
    group_label: "Workforce"
    description: "Average of the month-end headcounts in the period. Denominator of the turnover rate."
    type: number
    sql: SAFE_DIVIDE(SUM(${headcount_raw}), COUNT(DISTINCT ${TABLE}.month_start_date)) ;;
    value_format_name: decimal_1
  }

  measure: voluntary_exits {
    label: "Voluntary Exits"
    group_label: "Workforce"
    description: "Full-time and part-time employees who left voluntarily, with a termination date in the period."
    type: sum
    sql: ${TABLE}.voluntary_exits ;;
    value_format_name: decimal_0
    drill_fields: [drill_workforce*]
  }

  measure: voluntary_turnover_rate {
    label: "Voluntary Turnover Rate"
    group_label: "Workforce"
    description: "Voluntary exits in the period / average month-end headcount of the period. Not annualized: a quarter shows a quarterly rate."
    type: number
    sql: SAFE_DIVIDE(${voluntary_exits}, ${average_month_end_headcount}) ;;
    value_format_name: percent_1
    drill_fields: [drill_workforce*]
  }

  # ================================================================== same period last year
  measure: gross_payroll_prior_year {
    label: "Gross Payroll (Same Period Last Year)"
    group_label: "Prior Year"
    type: sum
    sql: ${TABLE}.prior_year_gross_payroll_usd ;;
    value_format_name: usd_0
  }

  measure: overtime_pay_prior_year {
    label: "Overtime Pay (Same Period Last Year)"
    group_label: "Prior Year"
    type: sum
    sql: ${TABLE}.prior_year_overtime_usd ;;
    value_format_name: usd_0
  }

  measure: overtime_pct_prior_year {
    label: "Overtime % (Same Period Last Year)"
    group_label: "Prior Year"
    type: number
    sql: SAFE_DIVIDE(${overtime_pay_prior_year}, ${gross_payroll_prior_year}) ;;
    value_format_name: percent_1
  }

  measure: fully_loaded_cost_prior_year {
    label: "Fully Loaded Cost (Same Period Last Year)"
    group_label: "Prior Year"
    type: number
    sql: ${gross_payroll_prior_year} + SUM(${TABLE}.prior_year_employer_cost_usd) ;;
    value_format_name: usd_0
  }

  measure: voluntary_turnover_rate_prior_year {
    label: "Voluntary Turnover Rate (Same Period Last Year)"
    group_label: "Prior Year"
    type: number
    sql: SAFE_DIVIDE(SUM(${TABLE}.prior_year_voluntary_exits),
                     SAFE_DIVIDE(SUM(${prior_year_headcount_raw}), COUNT(DISTINCT IF(${prior_year_headcount_raw} IS NOT NULL, ${TABLE}.month_start_date, NULL)))) ;;
    value_format_name: percent_1
  }

  # ================================================================== drill sets
  set: drill_department_month {
    fields: [departments.division, departments.department_name, period_month, gross_payroll, budgeted_gross_payroll, budget_variance_pct, overtime_pay, overtime_pct, employer_cost]
  }

  set: drill_workforce {
    fields: [departments.division, departments.department_name, period_month, headcount, budgeted_headcount, voluntary_exits]
  }
}
