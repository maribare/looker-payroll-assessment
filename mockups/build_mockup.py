"""
Builds mockups/dashboard_mockup.html from mockups/mockup_data.json
(numbers produced by validation/compute_answers.py, default filter = FY2027-Q1).
The HTML is a visual mockup of workforce_payroll_executive.dashboard.lookml.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
d = json.loads((HERE / "mockup_data.json").read_text())
k, depts, trend = d["kpi"], d["dept"], d["trend"]

BLUE, GREY, MUTED, INK, INK2, GRID = "#2a78d6", "#c3c2b7", "#898781", "#0b0b0b", "#52514e", "#e1e0d9"
GOOD_TXT, BAD, GOOD = "#006300", "#d03b3b", "#0ca30c"
MONTHS = {"01": "Jan", "02": "Feb", "03": "Mar", "04": "Apr", "05": "May", "06": "Jun",
          "07": "Jul", "08": "Aug", "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dec"}


def money(x, dec=0):
    return f"${x:,.{dec}f}"


def mlabel(m):
    y, mm = m.split("-")
    return f"{MONTHS[mm]} {y[2:]}"


def delta(cur, prev, reverse=False, pts=True):
    diff = (cur - prev) * 100
    worse = diff > 0 if reverse else diff < 0
    color = BAD if worse else GOOD_TXT
    arrow = "&#9650;" if diff > 0 else "&#9660;"
    unit = " pts" if pts else ""
    return f'<span style="color:{color}">{arrow} {abs(diff):.2f}{unit}</span>'


# ------------------------------------------------------------------ KPI tiles
var = k["var"]
var_txt = (f'<span style="color:{BAD}">&#9650; {var:+.1%} over budget</span>' if var > 0.02 else
           f'<span style="color:{GOOD_TXT}">&#9660; {var:.1%} under budget</span>' if var < -0.02 else
           f'<span style="color:{INK2}">&#9679; {var:+.1%} on budget</span>')
hc_diff = k["hc"] - k["hc_budget"]
kpis = [
    ("Budget variance", var_txt, f'{money(k["gross"])} actual gross payroll<br>vs {money(k["budget"])} budget'),
    ("Overtime %", f'{k["ot_pct"]:.1%}', f'{delta(k["ot_pct"], k["ot_pct_ly"], reverse=True)} vs same period last year ({k["ot_pct_ly"]:.1%})'),
    ("Headcount (end of period)", f'{k["hc"]:.0f}', f'<span style="color:{INK2}">{hc_diff:+.0f} vs budgeted headcount ({k["hc_budget"]:.0f})</span>'),
    ("Voluntary turnover (period)", f'{k["turn"]:.1%}', f'{delta(k["turn"], k["turn_ly"], reverse=True)} vs same period last year ({k["turn_ly"]:.1%})'),
]
kpi_html = "".join(
    f'<div class="tile kpi"><div class="tile-title">{t}<span class="note" title="Chart note">i</span></div>'
    f'<div class="big">{v}</div><div class="sub">{s}</div></div>' for t, v, s in kpis)

# ------------------------------------------------------------------ bullet table
rows = sorted(depts, key=lambda r: r["var"], reverse=True)
trs = []
for r in rows:
    used = r["used"]
    width = 100 if used > 1.3 else used * 76.92
    color = BAD if used > 1.02 else GOOD if used < 0.98 else MUTED
    v = r["var"]
    vtxt = (f'<span style="color:{BAD}">&#9650; {v:+.1%} over</span>' if v > 0.02 else
            f'<span style="color:{GOOD_TXT}">&#9660; {v:.1%} under</span>' if v < -0.02 else
            f'<span style="color:{INK2}">&#9679; {v:+.1%} on budget</span>')
    trs.append(
        f'<tr title="{r["name"]}: {money(r["gross"])} of {money(r["budget"])} budget ({used:.0%})">'
        f'<td>{r["name"]}</td>'
        f'<td><div class="bullet"><div class="fill" style="width:{width:.1f}%;background:{color}"></div>'
        f'<div class="target"></div></div><span class="bl">{used:.0%} of budget</span></td>'
        f'<td>{vtxt}</td><td class="num">{money(r["gross"])}</td><td class="num">{money(r["budget"])}</td>'
        f'<td class="num">{money(r["fully"])}</td></tr>')
tot_g, tot_b = sum(r["gross"] for r in rows), sum(r["budget"] for r in rows)
trs.append(f'<tr class="total"><td>Total</td><td></td><td>{var_txt}</td><td class="num">{money(tot_g)}</td>'
           f'<td class="num">{money(tot_b)}</td><td class="num">{money(sum(r["fully"] for r in rows))}</td></tr>')
table_html = ('<table><thead><tr><th>Department</th><th>Actual vs budget</th><th>Budget variance</th>'
              '<th class="num">Gross payroll</th><th class="num">Budget</th><th class="num">Fully loaded</th></tr></thead>'
              f'<tbody>{"".join(trs)}</tbody></table>')

# ------------------------------------------------------------------ OT % by department (horizontal grouped bars)
ot_rows = sorted(depts, key=lambda r: r["ot_pct"], reverse=True)
W, left, top, bar_h, gap, group = 500, 175, 10, 11, 2, 34
xmax = 0.10
plot_w = W - left - 60
svg = [f'<svg viewBox="0 0 {W} {top + group * len(ot_rows) + 30}" width="100%" role="img" aria-label="Overtime % by department">']
for i in range(0, 11, 2):
    x = left + plot_w * (i / 100) / xmax
    svg.append(f'<line x1="{x:.1f}" y1="{top - 4}" x2="{x:.1f}" y2="{top + group * len(ot_rows)}" stroke="{GRID}" stroke-width="1"/>')
    svg.append(f'<text x="{x:.1f}" y="{top + group * len(ot_rows) + 16}" class="axis" text-anchor="middle">{i}%</text>')
for i, r in enumerate(ot_rows):
    y = top + i * group + 4
    svg.append(f'<text x="{left - 10}" y="{y + bar_h + 2}" class="lab" text-anchor="end">{r["name"]}</text>')
    w1 = plot_w * r["ot_pct"] / xmax
    w0 = plot_w * (r["ot_pct_ly"] or 0) / xmax
    svg.append(f'<rect x="{left}" y="{y}" width="{max(w1, 1):.1f}" height="{bar_h}" rx="2" fill="{BLUE}"><title>{r["name"]} – this period: {r["ot_pct"]:.2%}</title></rect>')
    svg.append(f'<rect x="{left}" y="{y + bar_h + gap}" width="{max(w0, 1):.1f}" height="{bar_h}" rx="2" fill="{GREY}"><title>{r["name"]} – same period last year: {(r["ot_pct_ly"] or 0):.2%}</title></rect>')
    svg.append(f'<text x="{left + w1 + 6:.1f}" y="{y + bar_h - 1}" class="val">{r["ot_pct"]:.1%}</text>')
svg.append("</svg>")
ot_svg = "".join(svg)

# ------------------------------------------------------------------ OT cost by month (columns)
W2, H2, l2, b2, t2 = 600, 250, 56, 34, 16
vals = [t["ot"] for t in trend]
ymax = 40000
pw, ph = W2 - l2 - 12, H2 - b2 - t2
step = pw / len(trend)
svg = [f'<svg viewBox="0 0 {W2} {H2}" width="100%" role="img" aria-label="Overtime cost by month">']
for yv in range(0, ymax + 1, 10000):
    y = t2 + ph - ph * yv / ymax
    svg.append(f'<line x1="{l2}" y1="{y:.1f}" x2="{W2 - 12}" y2="{y:.1f}" stroke="{GRID}"/>')
    svg.append(f'<text x="{l2 - 8}" y="{y + 4:.1f}" class="axis" text-anchor="end">${yv // 1000}K</text>')
i_max = vals.index(max(vals))
for i, t in enumerate(trend):
    h = ph * t["ot"] / ymax
    x = l2 + i * step + step * 0.18
    w = step * 0.64
    y = t2 + ph - h
    svg.append(f'<path d="M{x:.1f},{t2 + ph} V{y + 4:.1f} Q{x:.1f},{y:.1f} {x + 4:.1f},{y:.1f} H{x + w - 4:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + 4:.1f} V{t2 + ph} Z" fill="{BLUE}">'
               f'<title>{mlabel(t["month"])}: {money(t["ot"])} overtime ({t["ot_pct"]:.1%} of gross)</title></path>')
    if i % 2 == 0 or i == len(trend) - 1:
        svg.append(f'<text x="{x + w / 2:.1f}" y="{H2 - 14}" class="axis" text-anchor="middle">{mlabel(t["month"])}</text>')
    if i in (i_max, len(trend) - 1):
        svg.append(f'<text x="{x + w / 2:.1f}" y="{y - 6:.1f}" class="val" text-anchor="middle">${t["ot"] / 1000:.1f}K</text>')
svg.append(f'<line x1="{l2}" y1="{t2 + ph}" x2="{W2 - 12}" y2="{t2 + ph}" stroke="{GREY}"/>')
svg.append("</svg>")
ot_trend_svg = "".join(svg)

# ------------------------------------------------------------------ headcount vs budget (lines)
ymin, ymax = 160, 190
svg = [f'<svg viewBox="0 0 {W2} {H2}" width="100%" role="img" aria-label="Headcount vs budgeted headcount">']
for yv in range(ymin, ymax + 1, 10):
    y = t2 + ph - ph * (yv - ymin) / (ymax - ymin)
    svg.append(f'<line x1="{l2}" y1="{y:.1f}" x2="{W2 - 60}" y2="{y:.1f}" stroke="{GRID}"/>')
    svg.append(f'<text x="{l2 - 8}" y="{y + 4:.1f}" class="axis" text-anchor="end">{yv}</text>')
pw3 = W2 - l2 - 72
step3 = pw3 / (len(trend) - 1)


def pts(key):
    return [(l2 + i * step3, t2 + ph - ph * (t[key] - ymin) / (ymax - ymin)) for i, t in enumerate(trend)]


hc_pts, bud_pts = pts("headcount"), pts("budget_hc")
svg.append(f'<polyline points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in bud_pts)}" fill="none" stroke="{MUTED}" stroke-width="2" stroke-dasharray="5 4"/>')
svg.append(f'<polyline points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in hc_pts)}" fill="none" stroke="{BLUE}" stroke-width="2"/>')
for (x, y), t in zip(hc_pts, trend):
    svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="{BLUE}" stroke="#fcfcfb" stroke-width="2"><title>{mlabel(t["month"])}: headcount {t["headcount"]:.0f}, budget {t["budget_hc"]:.0f}, voluntary exits {t["vol_terms"]:.0f}</title></circle>')
for i, t in enumerate(trend):
    if i % 2 == 0 or i == len(trend) - 1:
        svg.append(f'<text x="{hc_pts[i][0]:.1f}" y="{H2 - 14}" class="axis" text-anchor="middle">{mlabel(t["month"])}</text>')
svg.append(f'<text x="{hc_pts[-1][0] + 8:.1f}" y="{hc_pts[-1][1] + 4:.1f}" class="val">Actual {trend[-1]["headcount"]:.0f}</text>')
svg.append(f'<text x="{bud_pts[-1][0] + 8:.1f}" y="{bud_pts[-1][1] - 4:.1f}" class="lab">Budget {trend[-1]["budget_hc"]:.0f}</text>')
svg.append("</svg>")
hc_svg = "".join(svg)


def legend(items):
    return '<div class="legend">' + "".join(
        f'<span><i style="background:{c};{extra}"></i>{n}</span>' for n, c, extra in items) + "</div>"


html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Executive Dashboard Mockup</title>
<style>
  :root {{ --page:#f9f9f7; --surface:#fcfcfb; --ink:{INK}; --ink2:{INK2}; --muted:{MUTED}; --grid:{GRID}; --line:#e1e0d9; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--page); color:var(--ink); font:14px/1.4 "Segoe UI", system-ui, -apple-system, sans-serif; }}
  .wrap {{ width:1360px; margin:0 auto; padding:20px 16px 28px; }}
  header {{ display:flex; justify-content:space-between; align-items:flex-end; margin-bottom:12px; }}
  h1 {{ font-size:22px; margin:0; font-weight:600; }}
  .subtitle {{ color:var(--ink2); font-size:13px; margin-top:2px; }}
  .stamp {{ color:var(--muted); font-size:12px; }}
  .filters {{ display:flex; gap:8px; margin:10px 0 16px; }}
  .chip {{ background:var(--surface); border:1px solid var(--line); border-radius:6px; padding:6px 10px; font-size:13px; }}
  .chip b {{ font-weight:600; }} .chip span {{ color:var(--muted); margin-right:6px; }}
  .grid {{ display:grid; grid-template-columns:repeat(24, 1fr); gap:12px; }}
  .tile {{ background:var(--surface); border:1px solid var(--line); border-radius:8px; padding:14px 16px; }}
  .tile-title {{ font-size:14px; font-weight:600; display:flex; justify-content:space-between; align-items:center; margin-bottom:6px; }}
  .note {{ display:inline-flex; width:16px; height:16px; border-radius:50%; border:1px solid var(--muted); color:var(--muted); font-size:10px; align-items:center; justify-content:center; font-style:italic; }}
  .kpi {{ grid-column:span 6; min-height:128px; }}
  .kpi .tile-title {{ color:var(--ink2); font-weight:500; }}
  .big {{ font-size:30px; font-weight:600; margin:4px 0 6px; font-variant-numeric:tabular-nums; }}
  .kpi:first-child .big {{ font-size:22px; padding-top:8px; }}
  .sub {{ font-size:12.5px; color:var(--ink2); }}
  .w13 {{ grid-column:span 14; }} .w11 {{ grid-column:span 10; }} .w12 {{ grid-column:span 12; }}
  table {{ width:100%; border-collapse:collapse; font-size:12.5px; font-variant-numeric:tabular-nums; }}
  th {{ text-align:left; color:var(--ink2); font-weight:500; border-bottom:1px solid var(--line); padding:6px 6px; }}
  td {{ padding:6px 6px; border-bottom:1px solid #f0efec; vertical-align:middle; }}
  tr.total td {{ font-weight:600; border-top:1px solid #c3c2b7; border-bottom:none; }}
  .num {{ text-align:right; }}
  .bullet {{ position:relative; height:18px; width:100px; background:#f0efec; border-radius:3px; display:inline-block; vertical-align:middle; }}
  .bullet .fill {{ position:absolute; left:0; top:4px; height:10px; border-radius:2px; }}
  .bullet .target {{ position:absolute; left:76.92%; top:0; height:18px; width:2px; background:#0b0b0b; }}
  .bl {{ font-size:11px; color:var(--ink2); margin-left:8px; white-space:nowrap; }}
  td.num, td:first-child {{ white-space:nowrap; }}
  svg text.axis {{ font-size:11px; fill:var(--muted); }}
  svg text.lab {{ font-size:12px; fill:var(--ink2); }}
  svg text.val {{ font-size:11.5px; fill:var(--ink); font-weight:600; }}
  .legend {{ display:flex; gap:16px; font-size:12px; color:var(--ink2); margin:0 0 6px; }}
  .legend i {{ display:inline-block; width:12px; height:10px; border-radius:2px; margin-right:6px; vertical-align:middle; }}
  .foot {{ margin-top:14px; color:var(--muted); font-size:12px; }}
</style></head>
<body><div class="wrap">
<header><div><h1>Workforce &amp; Payroll – Executive Overview</h1>
<div class="subtitle">Are we within the payroll budget? Where is overtime growing? Is our workforce stable?</div></div>
<div class="stamp">Data through September 2026 · refreshed after each Dataform run</div></header>
<div class="filters">
  <div class="chip"><span>Fiscal Year</span><b>FY2027</b></div>
  <div class="chip"><span>Fiscal Quarter</span><b>is any value</b></div>
  <div class="chip"><span>Division</span><b>is any value</b></div>
  <div class="chip"><span>Department</span><b>is any value</b></div>
</div>
<div class="grid">
  {kpi_html}
  <div class="tile w13"><div class="tile-title">Where Are We Over or Under Budget?<span class="note">i</span></div>{table_html}</div>
  <div class="tile w11"><div class="tile-title">Overtime % by Department – This Period vs Last Year<span class="note">i</span></div>
    {legend([("This period (FY2027-Q1)", BLUE, ""), ("Same period last year (FY2026-Q1)", GREY, "")])}{ot_svg}</div>
  <div class="tile w12"><div class="tile-title">Overtime Cost by Month (last 15 months)<span class="note">i</span></div>{ot_trend_svg}</div>
  <div class="tile w12"><div class="tile-title">Headcount vs Budgeted Headcount by Month<span class="note">i</span></div>
    {legend([("Headcount (month end)", BLUE, ""), ("Budgeted headcount", MUTED, "height:2px;")])}{hc_svg}</div>
</div>
<div class="foot">Mockup of lookml/dashboards/workforce_payroll_executive.dashboard.lookml. Figures computed from the assessment dataset with validation/compute_answers.py. Hover any bar, point or row for exact values.</div>
</div></body></html>"""
(HERE / "dashboard_mockup.html").write_text(html, encoding="utf-8")
print("written", HERE / "dashboard_mockup.html")
