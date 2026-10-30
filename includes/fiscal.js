// Fiscal year runs July 1 - June 30 and is named after the year in which it ends
// (FY2026 = July 2025 - June 2026). Adding 6 months to a date moves it onto its
// fiscal calendar: July becomes January (period 1) of the next year.

function fiscalYear(dateExpr) {
  return `EXTRACT(YEAR FROM DATE_ADD(${dateExpr}, INTERVAL 6 MONTH))`;
}

function fiscalYearLabel(dateExpr) {
  return `CONCAT('FY', CAST(${fiscalYear(dateExpr)} AS STRING))`;
}

function fiscalPeriod(dateExpr) {
  return `EXTRACT(MONTH FROM DATE_ADD(${dateExpr}, INTERVAL 6 MONTH))`;
}

function fiscalQuarter(dateExpr) {
  return `DIV(${fiscalPeriod(dateExpr)} - 1, 3) + 1`;
}

function fiscalQuarterLabel(dateExpr) {
  return `CONCAT(${fiscalYearLabel(dateExpr)}, '-Q', CAST(${fiscalQuarter(dateExpr)} AS STRING))`;
}

module.exports = { fiscalYear, fiscalYearLabel, fiscalPeriod, fiscalQuarter, fiscalQuarterLabel };
