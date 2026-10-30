"""
Independent check of the gold-layer logic, written in pandas on the raw CSVs.

It applies the same cleaning rules as the Dataform SQL (see README) and prints
the four answers, so the numbers in the README can be reproduced without BigQuery.

Usage:  python validation/compute_answers.py [path/to/raw/csvs]
"""
import sys
from pathlib import Path

import pandas as pd

RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "data" / "raw"
pd.set_option("display.width", 200)

FY2026 = (pd.Timestamp("2025-07-01"), pd.Timestamp("2026-06-30"))
Q1_FY2027 = (pd.Timestamp("2026-07-01"), pd.Timestamp("2026-09-30"))


def is_test(s: pd.Series) -> pd.Series:
    return s.str.upper().str.startswith("TEST")


# ---------------------------------------------------------------- load (all as text, like a bronze layer)
lines_raw = pd.read_csv(RAW / "payroll_lines.csv", dtype=str)
contrib_raw = pd.read_csv(RAW / "employer_contributions.csv", dtype=str)
emp_raw = pd.read_csv(RAW / "employees.csv", dtype=str)
budget = pd.read_csv(RAW / "budget.csv", dtype=str)
departments = pd.read_csv(RAW / "departments.csv", dtype=str)

# ---------------------------------------------------------------- payroll lines -> valid earning lines
lines = lines_raw.copy()
# Issue: 780 amounts use a thousands separator ("2,163.20").
lines["amount"] = pd.to_numeric(lines["amount_usd"].str.replace(",", "", regex=False))
lines["pay_date"] = pd.to_datetime(lines["pay_date"])
# Issue: 42 lines were ingested twice. Keep the first ingestion of each payroll_line_id.
lines = lines.sort_values("_ingested_at").drop_duplicates("payroll_line_id", keep="first")
# Issue: VOID lines repeat the original (positive) amount in a later pay run.
# The voided original and the VOID line are both excluded; the replacement line stays.
voided_ids = set(lines.loc[lines.line_status == "VOID", "voids_line_id"])
valid = lines[
    (lines.line_status == "POSTED")
    & ~lines.payroll_line_id.isin(voided_ids)
    & ~is_test(lines.employee_id)  # Issue: TEST-001 / TEST-002 test accounts
].copy()
valid["month"] = valid.pay_date.dt.to_period("M")

pay_run_dates = lines.groupby("pay_run_id").pay_date.max()

# ---------------------------------------------------------------- employer contributions
contrib = contrib_raw[~is_test(contrib_raw.employee_id)].copy()
contrib["amount"] = pd.to_numeric(contrib["amount_usd"].str.replace(",", "", regex=False))
contrib["pay_date"] = contrib.pay_run_id.map(pay_run_dates)
# Cost department = department charged on that employee's lines in the same pay run
run_dept = valid.drop_duplicates(["pay_run_id", "employee_id"]).set_index(["pay_run_id", "employee_id"]).department_id
contrib["department_id"] = [run_dept.get((r, e)) for r, e in zip(contrib.pay_run_id, contrib.employee_id)]
contrib["month"] = contrib.pay_date.dt.to_period("M")

# ---------------------------------------------------------------- employees
emp_raw["_loaded_at"] = pd.to_datetime(emp_raw["_loaded_at"].str.replace(" UTC", ""))
emp_raw = emp_raw[~is_test(emp_raw.employee_id)]
current = emp_raw.sort_values("_loaded_at").drop_duplicates("employee_id", keep="last").copy()
current["hire_date"] = pd.to_datetime(current.hire_date)
current["termination_date"] = pd.to_datetime(current.termination_date)
workforce = current[current.employment_type.isin(["FULL_TIME", "PART_TIME"])]

# Department history (SCD2): each snapshot is valid from its load date; the first one from the beginning.
hist = emp_raw.sort_values(["employee_id", "_loaded_at"]).copy()
hist["valid_from"] = hist._loaded_at.dt.normalize()
hist.loc[~hist.employee_id.duplicated(), "valid_from"] = pd.Timestamp("1900-01-01")
hist["valid_to"] = hist.groupby("employee_id").valid_from.shift(-1) - pd.Timedelta(days=1)
hist["valid_to"] = hist.valid_to.fillna(pd.Timestamp("9999-12-31"))
# Issue: 4 employees have no department -> take the latest department charged on their payroll lines.
latest_line_dept = valid.sort_values("pay_date").groupby("employee_id").department_id.last()
hist["department_id"] = hist.department_id.fillna(hist.employee_id.map(latest_line_dept))


def active_on(day: pd.Timestamp) -> pd.DataFrame:
    """FULL_TIME / PART_TIME employees active on `day` (hired on or before, not terminated on or before)."""
    a = workforce[(workforce.hire_date <= day) & (workforce.termination_date.isna() | (workforce.termination_date > day))]
    h = hist[(hist.valid_from <= day) & (hist.valid_to >= day)][["employee_id", "department_id"]]
    return a.drop(columns="department_id").merge(h, on="employee_id", how="left")


def month_ends(start, end):
    return list(pd.date_range(start, end, freq="ME"))


# ================================================================ answers
print("=" * 70)
in_fy26 = valid.pay_date.between(*FY2026)
gross_fy26 = valid.loc[in_fy26, "amount"].sum()
employer_fy26 = contrib.loc[contrib.pay_date.between(*FY2026), "amount"].sum()
print("Q1  Fully loaded payroll cost FY2026")
print(f"    gross payroll   = {gross_fy26:>15,.2f}")
print(f"    employer cost   = {employer_fy26:>15,.2f}")
print(f"    fully loaded    = {gross_fy26 + employer_fy26:>15,.2f}")

print("\nQ2  Overtime % by department, Q1 FY2027 (Jul-Sep 2026)")
q = valid[valid.pay_date.between(*Q1_FY2027)]
ot = q.assign(ot=q.amount.where(q.earning_type == "OVERTIME", 0)).groupby("department_id")[["ot", "amount"]].sum()
ot["ot_pct"] = ot.ot / ot.amount
ot = ot.join(departments.set_index("department_id").department_name).sort_values("ot_pct", ascending=False)
print(ot.to_string(formatters={"ot": "{:,.2f}".format, "amount": "{:,.2f}".format, "ot_pct": "{:.2%}".format}))

print("\nQ3  Voluntary turnover rate FY2026")
fy_month_ends = month_ends("2025-07-01", "2026-06-30")
hc_by_month = pd.Series({d.date(): len(active_on(d)) for d in fy_month_ends})
avg_hc = hc_by_month.mean()
vol = workforce[(workforce.termination_reason == "VOLUNTARY") & workforce.termination_date.between(*FY2026)]
print(f"    month-end headcounts: {hc_by_month.tolist()}")
print(f"    voluntary terminations = {len(vol)}, average month-end headcount = {avg_hc:.2f}")
print(f"    voluntary turnover     = {len(vol) / avg_hc:.2%}")

print("\nQ4  Headcount on 2026-09-30")
hc = active_on(pd.Timestamp("2026-09-30"))
print(f"    headcount = {len(hc)}   ({hc.employment_type.value_counts().to_dict()})")

# ================================================================ data-quality impact (for README)
print("\n" + "=" * 70 + "\nData issue impact")
dup_rows = len(lines_raw) - lines_raw.payroll_line_id.nunique()
print(f"    duplicated line rows: {dup_rows}, amount = {pd.to_numeric(lines_raw.amount_usd.str.replace(',', ''))[lines_raw.payroll_line_id.duplicated()].sum():,.2f}")
vo = lines[lines.payroll_line_id.isin(voided_ids)]
print(f"    voided originals: {len(vo)}, amount = {vo.amount.sum():,.2f}; VOID lines amount = {lines[lines.line_status == 'VOID'].amount.sum():,.2f}")
print(f"    test-account lines amount = {lines[is_test(lines.employee_id) & (lines.line_status == 'POSTED')].amount.sum():,.2f}, contributions = {pd.to_numeric(contrib_raw.amount_usd[is_test(contrib_raw.employee_id)]).sum():,.2f}")
print(f"    comma-formatted amounts: {lines_raw.amount_usd.str.contains(',').sum()} lines, {pd.to_numeric(lines_raw.amount_usd[lines_raw.amount_usd.str.contains(',')].str.replace(',', '')).sum():,.2f}")
naive = pd.to_numeric(lines_raw.amount_usd, errors="coerce")
print(f"    naive SUM(all rows, cast fails -> NULL) FY2026 = {naive[pd.to_datetime(lines_raw.pay_date).between(*FY2026)].sum():,.2f} vs clean {gross_fy26:,.2f}")

# ================================================================ monthly summary (feeds the mockup)
monthly = (
    valid.assign(ot=valid.amount.where(valid.earning_type == "OVERTIME", 0))
    .groupby(["department_id", "month"])[["amount", "ot"]].sum()
    .rename(columns={"amount": "gross"})
    .join(contrib.groupby(["department_id", "month"]).amount.sum().rename("employer"))
)
b = budget.assign(month=pd.PeriodIndex(budget.calendar_month, freq="M"),
                  budget=pd.to_numeric(budget.budgeted_gross_payroll_usd),
                  budget_hc=pd.to_numeric(budget.budgeted_headcount)).set_index(["department_id", "month"])[["budget", "budget_hc"]]
monthly = monthly.join(b, how="outer").fillna(0)
hc_rows = []
for d in month_ends("2025-07-01", "2026-09-30"):
    a = active_on(d)
    for dept, n in a.department_id.value_counts().items():
        hc_rows.append((dept, d.to_period("M"), n))
monthly = monthly.join(pd.DataFrame(hc_rows, columns=["department_id", "month", "headcount"]).set_index(["department_id", "month"]))
vol_all = workforce[workforce.termination_reason == "VOLUNTARY"].copy()
vol_all["month"] = vol_all.termination_date.dt.to_period("M")
vol_all = vol_all.merge(hist[["employee_id", "department_id", "valid_from", "valid_to"]], on="employee_id")
vol_all = vol_all[(vol_all.valid_from <= vol_all.termination_date) & (vol_all.valid_to >= vol_all.termination_date)]
monthly = monthly.join(vol_all.groupby(["department_id_y", "month"]).size().rename("vol_terms").rename_axis(["department_id", "month"])).fillna(0)
out = Path(__file__).resolve().parent / "monthly_summary_check.csv"
monthly.reset_index().to_csv(out, index=False)
print(f"\nMonthly summary written to {out.name} ({len(monthly)} rows)")
tot = monthly.groupby("month")[["gross", "employer", "ot", "budget", "headcount", "budget_hc", "vol_terms"]].sum()
tot["var_pct"] = tot.gross / tot.budget - 1
tot["ot_pct"] = tot.ot / tot.gross
print(tot.to_string(float_format=lambda x: f"{x:,.3f}"))
