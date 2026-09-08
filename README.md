## Hospital Readmission Risk Scoring & Case Management Outreach


## Business Problem

  It's not just the patient who suffers when they have to be readmitted into the hospital, the hospital itself faces financial penalties when patients are readmitted within 30 days of discharge. Most analyses stop at describing which groups tend to be readmitted more like either older patients, certain diagnoses, certain discharge types. That's useful for a slide deck, but it doesn't help a case manager decide who to call on a Tuesday morning.

  This project answers a more operational question: given today's discharges, which specific patients should a case manager call within 48 hours to prevent an avoidable readmission?

  Using 10 years of data from 130 U.S. hospitals, I built a weighted risk-scoring system based on factors known at the moment of discharge (prior hospital utilization, diagnosis category, medication burden, diabetes management indicators, and age), sorted every patient into an outreach priority tier, and then validated that the tiers actually track real 30-day readmission outcomes, not just plausible-sounding risk factors. The end product is a call list, not just a report.



## Data & Tools

- Dataset: Diabetes 130-US Hospitals for Years 1999–2008 (UCI Machine Learning Repository, CC BY 4.0) — 200,000 patient encounters across 130 hospitals
- Database: MySQL Workbench
- Techniques used: CTEs, Views, Window Functions (`RANK`, `NTILE`), `CASE` risk scoring, correlated subqueries, multi-table joins, outcome validation



## Approach / Methodology

1. Data Cleaning
  Replaced placeholder missing values (`'?'`) with proper `NULL`s, dropped a column that was over 97% missing, kept only each patient's first encounter to avoid duplicate bias, and removed patients discharged to hospice or who died in the hospital. 

2. Exploratory analysis 
  Established baseline readmission rates by age, admission type, and diagnosis category to understand which factors were worth building into a scoring model.

3. Advanced analysis
  Built a reusable risk cohort with a CTE, used window functions to rank patients by medication burden within age groups and split patients into risk quartiles by prior utilization, and used a correlated subquery to isolate which diagnosis categories perform above the population-wide average readmission rate.

4. Risk scoring for outreach**
  Combined seven discharge-time risk factors into a single weighted score per patient, saved the scoring logic as a reusable SQL `VIEW`, and used it to generate a prioritized outreach list. Weights were set based on the strength of each factor from the exploratory analysis . 

5. Validation
  Checked the resulting outreach tiers against the real `readmitted` outcome column to confirm the model has practical value — the "CALL WITHIN 48 HOURS" tier should have a materially higher actual readmission rate than "ROUTINE FOLLOW-UP," or the scoring system isn't worth deploying.



Key SQL Techniques Used

- CTEs (Common Table Expressions) — staged a clean, reusable patient risk cohort once, then referenced it across multiple downstream queries instead of repeating the same subquery logic
- Views — encapsulated the entire risk-scoring formula into a single patient_risk_scores view, so the outreach list and the validation query always pull from one consistent source of truth
- Window functions — used RANK() OVER (PARTITION BY ...) to rank medication burden within age groups, and NTILE(4) to split patients into risk quartiles based on prior hospital utilization
- Weighted CASE-based risk scoring — converted seven raw clinical variables (prior visits, diagnosis, medication count, etc.) into point values and summed them into a single actionable priority score per patient
- Correlated subqueries with HAVING — compared each diagnosis category's readmission rate against the population-wide average calculated in the same query, isolating only the categories performing worse than average
- Multi-table joins — matched numeric hospital codes (discharge disposition, admission source) against reference tables to translate raw IDs into human-readable labels
- Outcome validation — cross-checked the model's risk tiers against real historical readmission outcomes to confirm the scoring system actually predicts risk, rather than just looking plausible on paper



## The Outreach Model

Each discharged patient is scored using seven factors known at discharge:

| Risk Factor | Points |
|---|---|
| 3+ prior inpatient visits | 30 |
| 2 prior inpatient visits | 20 |
| 1 prior inpatient visit | 10 |
| 2+ prior ER visits | 15 |
| 1 prior ER visit | 8 |
| Circulatory or diabetes diagnosis | 15 |
| 20+ medications | 10 |
| 11–20 medications | 5 |
| No A1C test performed during stay | 10 |
| Medication regimen changed at discharge | 5 |
| Age 65+ | 10 |

Patients are then sorted into outreach tiers:

| Total Score | Outreach Priority |
|---|---|
| 50+ | Call within 48 hours |
| 30–49 | Call within 1 week |
| Below 30 | Routine follow-up |



## Findings

1. Circulatory and diabetes diagnoses had the highest readmission rates** among all diagnosis categories, both exceeding the population average.
2. Prior inpatient visits were the strongest predictor of readmission** — patients with 2+ prior admissions showed substantially elevated risk, supporting prior-utilization as the leading factor in the risk model.
3. Discharge disposition mattered significantly** — patients discharged to certain facility types showed measurably different readmission rates than those discharged home.
4. Medication changes at discharge and A1C testing during the stay** both aligned with the original clinical research question this dataset was collected to investigate.
5. The 7-factor weighted risk score meaningfully separates high-risk from low-risk patients.** When validated against real outcomes, the "Call within 48 hours" tier showed a real 30-day readmission rate well above the population average, while the "Routine follow-up" tier trended below it — confirming the score has practical value as a triage tool, not just a descriptive one.



## Files

- `hospital_readmissions.sql` — data cleaning, mapping tables, exploratory analysis, advanced techniques
- `care_management_outreach.sql` — risk-scoring view, outreach list query, and outcome validation query


