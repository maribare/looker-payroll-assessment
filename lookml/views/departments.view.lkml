view: departments {
  sql_table_name: `payroll_gold.dim_department` ;;
  label: "Department"

  dimension: department_id {
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.department_id ;;
  }

  dimension: department_name {
    label: "Department"
    description: "For payroll cost: the department (cost center) charged on the pay line. For headcount: the department the employee belonged to on that date."
    sql: ${TABLE}.department_name ;;
  }

  dimension: division {
    label: "Division"
    description: "Group of departments: Administration, Programs, Advancement, Operations."
    sql: ${TABLE}.division ;;
  }

  dimension: cost_center {
    label: "Cost Center"
    sql: ${TABLE}.cost_center ;;
  }

  dimension: manager_employee_id {
    hidden: yes
    sql: ${TABLE}.manager_employee_id ;;
  }
}
