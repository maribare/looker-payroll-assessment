view: salary_by_job_title {
  label: "Average Pay by Job Title"

  # PDT: aggregated once per Dataform run. It contains no row for an individual,
  # so nothing in this explore can reveal one person's pay.
  derived_table: {
    datagroup_trigger: payroll_gold_refresh
    sql:
      WITH current_staff AS (
        SELECT job_title, annualized_base_pay_usd
        FROM `payroll_gold.dim_employee`
        WHERE counts_in_headcount          -- full-time and part-time, no contractors
          AND termination_date IS NULL
      ),
      grouped AS (
        -- Titles held by fewer than 5 people are pooled into one group
        SELECT
          IF(COUNT(*) OVER (PARTITION BY job_title) >= 5, job_title, 'Other titles (fewer than 5 people each)') AS job_title_group,
          annualized_base_pay_usd
        FROM current_staff
      )
      SELECT
        job_title_group,
        COUNT(*)                                        AS employee_count,
        -- rounded to the nearest $1,000 to make reverse-engineering harder
        ROUND(AVG(annualized_base_pay_usd), -3)         AS avg_base_pay_usd
      FROM grouped
      GROUP BY job_title_group
      HAVING COUNT(*) >= 5                              -- the pooled group too
      ;;
  }

  dimension: job_title_group {
    primary_key: yes
    label: "Job Title"
    sql: ${TABLE}.job_title_group ;;
  }

  dimension: employee_count_raw { hidden: yes type: number sql: ${TABLE}.employee_count ;; }
  dimension: avg_base_pay_raw   { hidden: yes type: number sql: ${TABLE}.avg_base_pay_usd ;; }

  measure: employees {
    label: "Employees"
    type: sum
    sql: ${employee_count_raw} ;;
    value_format_name: decimal_0
  }

  measure: average_base_pay {
    label: "Average Annual Base Pay (FTE)"
    description: "Average of annual salary, or hourly rate x 2,080 hours, for current full-time and part-time staff. Rounded to $1,000. Groups under 5 people are pooled."
    type: number
    # Weighted by headcount, so it stays right when several titles are combined
    sql: SAFE_DIVIDE(SUM(${avg_base_pay_raw} * ${employee_count_raw}), SUM(${employee_count_raw})) ;;
    value_format_name: usd_0
  }
}
