- dashboard: workforce_payroll_executive
  title: Workforce & Payroll – Executive Overview
  description: "Monthly leadership view: are we within the payroll budget, where is overtime growing, is the workforce stable?"
  layout: newspaper
  preferred_viewer: dashboards-next
  refresh: 24 hours

  filters:
  - name: fiscal_year
    title: Fiscal Year
    type: field_filter
    default_value: FY2027
    allow_multiple_values: false
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: workforce_payroll
    explore: department_monthly
    field: department_monthly.fiscal_year

  - name: fiscal_quarter
    title: Fiscal Quarter
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config:
      type: checkboxes
      display: popover
    model: workforce_payroll
    explore: department_monthly
    field: department_monthly.fiscal_quarter
    listens_to_filters: [fiscal_year]

  - name: division
    title: Division
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config:
      type: tag_list
      display: popover
    model: workforce_payroll
    explore: department_monthly
    field: departments.division

  - name: department
    title: Department
    type: field_filter
    default_value: ""
    allow_multiple_values: true
    required: false
    ui_config:
      type: tag_list
      display: popover
    model: workforce_payroll
    explore: department_monthly
    field: departments.department_name
    listens_to_filters: [division]

  elements:

  # ----------------------------------------------------------------- KPI row
  - name: kpi_budget_variance
    title: Payroll vs Budget
    model: workforce_payroll
    explore: department_monthly
    type: single_value
    fields: [department_monthly.budget_variance_pct, department_monthly.gross_payroll]
    show_single_value_title: true
    single_value_title: Budget variance
    show_comparison: true
    comparison_type: value
    show_comparison_label: true
    comparison_label: actual gross payroll
    note_state: collapsed
    note_display: hover
    note_text: "Single value: the first question is yes/no (are we within budget?). The Liquid color and words (over / under / on budget) answer it in one glance; the actual amount is shown below for scale."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 0
    col: 0
    width: 6
    height: 4

  - name: kpi_overtime_pct
    title: Overtime % of Gross Payroll
    model: workforce_payroll
    explore: department_monthly
    type: single_value
    fields: [department_monthly.overtime_pct, department_monthly.overtime_pct_prior_year]
    show_single_value_title: true
    single_value_title: Overtime %
    show_comparison: true
    comparison_type: change
    comparison_reverse_colors: true
    show_comparison_label: true
    comparison_label: vs same period last year
    note_state: collapsed
    note_display: hover
    note_text: "Single value with change vs the same period last year (avoids seasonality). Colors are reversed: an increase in overtime is shown as bad."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 0
    col: 6
    width: 6
    height: 4

  - name: kpi_headcount
    title: Headcount vs Budget
    model: workforce_payroll
    explore: department_monthly
    type: single_value
    fields: [department_monthly.headcount, department_monthly.budgeted_headcount]
    show_single_value_title: true
    single_value_title: Headcount (end of period)
    show_comparison: true
    comparison_type: change
    show_comparison_label: true
    comparison_label: vs budgeted headcount
    note_state: collapsed
    note_display: hover
    note_text: "Single value: headcount is a point-in-time number, so it is shown for the last day of the selected period and compared with the budgeted headcount for that month."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 0
    col: 12
    width: 6
    height: 4

  - name: kpi_voluntary_turnover
    title: Voluntary Turnover
    model: workforce_payroll
    explore: department_monthly
    type: single_value
    fields: [department_monthly.voluntary_turnover_rate, department_monthly.voluntary_turnover_rate_prior_year]
    show_single_value_title: true
    single_value_title: Voluntary turnover (period)
    show_comparison: true
    comparison_type: change
    comparison_reverse_colors: true
    show_comparison_label: true
    comparison_label: vs same period last year
    note_state: collapsed
    note_display: hover
    note_text: "Single value vs the same period last year. Not annualized: for one quarter it is the quarterly rate. Higher is shown as bad."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 0
    col: 18
    width: 6
    height: 4

  # ----------------------------------------------------------------- budget by department (custom visual)
  - name: budget_by_department
    title: Where Are We Over or Under Budget?
    model: workforce_payroll
    explore: department_monthly
    type: looker_grid
    fields: [departments.department_name, department_monthly.budget_bullet, department_monthly.budget_variance_pct, department_monthly.gross_payroll, department_monthly.budgeted_gross_payroll, department_monthly.fully_loaded_cost]
    sorts: [department_monthly.budget_variance_pct desc]
    show_row_numbers: false
    show_totals: true
    table_theme: white
    header_text_alignment: left
    note_state: collapsed
    note_display: hover
    note_text: "Table with an in-cell bullet bar (custom HTML): each department's spend against its own budget line, sorted worst first. A bar chart of variance % alone hides the amounts; a table alone is slow to scan. The bullet shows both."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 4
    col: 0
    width: 13
    height: 8

  # ----------------------------------------------------------------- overtime by department
  - name: overtime_by_department
    title: Overtime % by Department – This Period vs Last Year
    model: workforce_payroll
    explore: department_monthly
    type: looker_bar
    fields: [departments.department_name, department_monthly.overtime_pct, department_monthly.overtime_pct_prior_year]
    sorts: [department_monthly.overtime_pct desc]
    show_value_labels: true
    label_density: 25
    legend_position: center
    x_axis_gridlines: false
    y_axis_gridlines: true
    series_colors:
      department_monthly.overtime_pct: "#2a78d6"
      department_monthly.overtime_pct_prior_year: "#c3c2b7"
    series_labels:
      department_monthly.overtime_pct: This period
      department_monthly.overtime_pct_prior_year: Same period last year
    note_state: collapsed
    note_display: hover
    note_text: "Horizontal bars, sorted: department names stay readable and the ranking answers 'where'. The grey bar for last year shows where overtime is growing."
    listen:
      fiscal_year: department_monthly.fiscal_year
      fiscal_quarter: department_monthly.fiscal_quarter
      division: departments.division
      department: departments.department_name
    row: 4
    col: 13
    width: 11
    height: 8

  # ----------------------------------------------------------------- overtime trend (ignores the period filters on purpose)
  - name: overtime_trend
    title: Overtime Cost by Month (last 15 months)
    model: workforce_payroll
    explore: department_monthly
    type: looker_column
    fields: [department_monthly.period_month, department_monthly.overtime_pay]
    sorts: [department_monthly.period_month asc]
    series_colors:
      department_monthly.overtime_pay: "#2a78d6"
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_value_labels: false
    note_state: collapsed
    note_display: hover
    note_text: "Columns, one per month, in dollars: answers 'how much does it cost us' and shows whether it is growing. Overtime % is in the bar chart next to it rather than on a second axis, which would make two scales compete. Growth is a trend question, so this tile always shows the full history and only listens to Division and Department."
    listen:
      division: departments.division
      department: departments.department_name
    row: 12
    col: 0
    width: 12
    height: 8

  # ----------------------------------------------------------------- workforce stability trend
  - name: workforce_trend
    title: Headcount vs Budgeted Headcount by Month
    model: workforce_payroll
    explore: department_monthly
    type: looker_line
    fields: [department_monthly.period_month, department_monthly.headcount, department_monthly.budgeted_headcount]
    sorts: [department_monthly.period_month asc]
    series_colors:
      department_monthly.headcount: "#2a78d6"
      department_monthly.budgeted_headcount: "#898781"
    series_point_style:
      department_monthly.budgeted_headcount: none
    x_axis_gridlines: false
    y_axis_gridlines: true
    y_axis_zoom: true
    note_state: collapsed
    note_display: hover
    note_text: "Two lines on one scale: a stable workforce is a flat line that tracks its budget. Voluntary exits are in the KPI tile above. Full history, listens to Division and Department."
    listen:
      division: departments.division
      department: departments.department_name
    row: 12
    col: 12
    width: 12
    height: 8
