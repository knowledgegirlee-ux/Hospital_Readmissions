CREATE DATABASE hospital_readmissions;
USE hospital_readmissions;

SELECT COUNT(*)
FROM diabetic_data_raw;

SELECT * FROM
diabetic_data_raw
LIMIT 10;

ALTER TABLE diabetic_data_raw
	MODIFY diag_1 VARCHAR(10);


SET SQL_SAFE_UPDATES = 0;

UPDATE diabetic_data_raw
SET race = NULLIF(race, '?'),
	weight = NULLIF(weight, '?'),
    payer_code = NULLIF(payer_code, '?'),
    medical_specialty = NULLIF(medical_specialty, '?'),
    diag_1 = NULLIF(diag_1, '?'),
	diag_2 = NULLIF(diag_2, '?'),
	diag_3 = NULLIF(diag_3, '?');

SELECT
    ROUND(SUM(weight IS NULL) * 100.0 / COUNT(*), 1) AS per_missing_weight,
    ROUND(SUM(payer_code IS NULL) * 100.0 / COUNT(*), 1) AS per_missing_code,
    ROUND(SUM(medical_specialty IS NULL) * 100.0 / COUNT(*), 1) AS per_missing_specialty
FROM diabetic_data_raw;

SELECT
	patient_nbr,
    COUNT(*) AS encounter_count
FROM diabetic_data_raw
GROUP BY patient_nbr
HAVING COUNT(*) > 1
ORDER BY encounter_count DESC
LIMIT 10;

DROP TABLE IF EXISTS diabetic_data_dedup;

CREATE TABLE diabetic_data_dedup AS
SELECT t.*
FROM diabetic_data_raw AS t
INNER JOIN (
    SELECT patient_nbr, MIN(encounter_id) AS first_encounter
    FROM diabetic_data_raw
    GROUP BY patient_nbr
) first_enc
ON t.patient_nbr = first_enc.patient_nbr
AND t.encounter_id = first_enc.first_encounter;

SELECT COUNT(*) FROM diabetic_data_dedup;

SELECT
	discharge_disposition_id,
    COUNT(*) as encounter_count
FROM diabetic_data_raw
GROUP BY discharge_disposition_id
ORDER BY encounter_count DESC;

SELECT * FROM ids_mapping_raw
WHERE description LIKE '%hospice%' OR description LIKE '%expired%' OR description LIKE '%deceased%';

DELETE FROM diabetic_data_dedup
WHERE discharge_disposition_id IN (11, 13, 14, 19, 20, 21, 26);

-- FIX: drop first so this script can be re-run without erroring
DROP TABLE IF EXISTS discharge_disposition_map;
DROP TABLE IF EXISTS admission_source_map;

CREATE TABLE discharge_disposition_map (
	discharge_disposition_id INT,
    description VARCHAR(150)
);

CREATE TABLE admission_source_map (
	admission_source_id INT,
    description VARCHAR(150)
);

INSERT INTO discharge_disposition_map (discharge_disposition_id, description) VALUES
(1, 'Discharged to home'),
(2, 'Discharged/transferred to another short term hospital'),
(3, 'Discharged/transferred to SNF'),
(4, 'Discharged/transferred to ICF'),
(5, 'Discharged/transferred to another type of inpatient care institution'),
(6, 'Discharged/transferred to home with home health service'),
(7, 'Left AMA'),
(8, 'Discharged/transferred to home under care of Home IV provider'),
(9, 'Admitted as an inpatient to this hospital'),
(10, 'Neonate discharged to another hospital for neonatal aftercare'),
(11, 'Expired'),
(12, 'Still patient or expected to return for outpatient services'),
(13, 'Hospice / home'),
(14, 'Hospice / medical facility'),
(15, 'Discharged/transferred within this institution to Medicare approved swing bed'),
(16, 'Discharged/transferred/referred another institution for outpatient services'),
(17, 'Discharged/transferred/referred to this institution for outpatient services'),
(18, 'NULL'),
(19, 'Expired at home. Medicaid only, hospice.'),
(20, 'Expired in a medical facility. Medicaid only, hospice.'),
(21, 'Expired, place unknown. Medicaid only, hospice.'),
(22, 'Discharged/transferred to another rehab fac including rehab units of a hospital.'),
(23, 'Discharged/transferred to a long term care hospital.'),
(24, 'Discharged/transferred to a nursing facility certified under Medicaid but not certified under Medicare.'),
(25, 'Not Mapped'),
(26, 'Unknown/Invalid'),
(27, 'Discharged/transferred to a federal health care facility.'),
(28, 'Discharged/transferred/referred to a psychiatric hospital of psychiatric distinct part unit of a hospital'),
(29, 'Discharged/transferred to a Critical Access Hospital (CAH).'),
(30, 'Discharged/transferred to another Type of Health Care Institution not Defined Elsewhere');

INSERT INTO admission_source_map (admission_source_id, description) VALUES
(1, 'Physician Referral'),
(2, 'Clinic Referral'),
(3, 'HMO Referral'),
(4, 'Transfer from a hospital'),
(5, 'Transfer from a Skilled Nursing Facility (SNF)'),
(6, 'Transfer from another health care facility'),
(7, 'Emergency Room'),
(8, 'Court/Law Enforcement'),
(9, 'Not Available'),
(10, 'Transfer from critical access hospital'),
(11, 'Normal Delivery'),
(12, 'Premature Delivery'),
(13, 'Sick Baby'),
(14, 'Extramural Birth'),
(15, 'Not Available'),
(17, 'NULL'),
(18, 'Transfer From Another Home Health Agency'),
(19, 'Readmission to Same Home Health Agency'),
(20, 'Not Mapped'),
(21, 'Unknown/Invalid'),
(22, 'Transfer from hospital inpt/same fac reslt in a sep claim'),
(23, 'Born inside this hospital'),
(24, 'Born outside this hospital'),
(25, 'Transfer from Ambulatory Surgery Center'),
(26, 'Transfer from Hospice');

ALTER TABLE diabetic_data_dedup ADD COLUMN age_midpoint INT;

UPDATE diabetic_data_dedup
SET age_midpoint = CASE
    WHEN age = '[0-10)'   THEN 5
    WHEN age = '[10-20)'  THEN 15
    WHEN age = '[20-30)'  THEN 25
    WHEN age = '[30-40)'  THEN 35
    WHEN age = '[40-50)'  THEN 45
    WHEN age = '[50-60)'  THEN 55
    WHEN age = '[60-70)'  THEN 65
    WHEN age = '[70-80)'  THEN 75
    WHEN age = '[80-90)'  THEN 85
    WHEN age = '[90-100)' THEN 95
END;

WITH patient_risk_base AS (
	SELECT
		encounter_id,
        patient_nbr,
        age_midpoint,
        num_medications,
        number_inpatient,
        number_emergency,
        diag_1,
        readmitted,
        CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END AS is_readmitted_30
	FROM diabetic_data_dedup
)
SELECT * FROM patient_risk_base
LIMIT 20;

WITH patient_risk_base AS (
	SELECT
		encounter_id, age_midpoint, num_medications, readmitted,
        CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END AS is_readmitted_30
	FROM diabetic_data_dedup
)
SELECT
	encounter_id,
    age_midpoint,
    num_medications,
    RANK() OVER (PARTITION BY age_midpoint ORDER BY num_medications DESC) as med_rank_age_group
FROM patient_risk_base
ORDER BY age_midpoint, med_rank_age_group
LIMIT 200;

WITH patient_risk_base AS (
	SELECT
		encounter_id, number_inpatient, readmitted,
        CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END AS is_readmitted_30
     FROM diabetic_data_dedup
)
SELECT
	encounter_id,
    number_inpatient,
    NTILE(4) OVER (ORDER BY number_inpatient DESC) as risk_quartile
FROM patient_risk_base;

WITH diag_categorized AS (
	SELECT
		encounter_id,
        readmitted,
        CASE
			WHEN diag_1 LIKE '250%' THEN 'Diabetes'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 390 AND 459 THEN 'CIRCULATORY'
			WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 460 AND 519 THEN 'Respiratory'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 520 AND 579 THEN 'Digestive'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 580 AND 629 THEN 'Genitourinary'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 800 AND 999 THEN 'Injury'
		ELSE 'Other'
	END AS diagnosis_category,
    CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END AS is_readmitted_30
	FROM diabetic_data_dedup
    WHERE diag_1 IS NOT NULL
)
SELECT
	diagnosis_category,
    COUNT(*) AS total_encounters,
    ROUND(AVG(is_readmitted_30) * 100, 1) AS readmission_rate_pct
FROM diag_categorized
GROUP BY diagnosis_category
HAVING AVG(is_readmitted_30) > (
	SELECT AVG(is_readmitted_30) FROM diag_categorized
)
ORDER BY readmission_rate_pct DESC;

SELECT
	`change`,
    COUNT(*) as total_encounters,
	ROUND(SUM(readmitted = '<30') / COUNT(*) * 100, 1) AS readmission_rate_pct
FROM diabetic_data_dedup
GROUP BY `change`;

SELECT
	m.description as discharge_disposition,
    COUNT(*) AS total_encounters,
	ROUND(SUM(d.readmitted = '<30') / COUNT(*) * 100, 1) AS readmission_rate_pct
FROM diabetic_data_dedup as d
JOIN discharge_disposition_map as m
ON d.discharge_disposition_id = m.discharge_disposition_id
GROUP BY m.description
HAVING COUNT(*) > 100
ORDER BY readmission_rate_pct DESC
LIMIT 10;

SELECT
	A1Cresult,
    COUNT(*) as total_encounters,
	ROUND(SUM(readmitted = '<30') / COUNT(*) * 100, 1) AS readmission_rate_pct
FROM diabetic_data_dedup
GROUP BY A1Cresult;

DROP VIEW IF EXISTS patient_risk_scores;

CREATE VIEW patient_risk_scores AS
WITH risk_factors AS (
    SELECT
        d.encounter_id,
        d.patient_nbr,
        d.age,
        d.age_midpoint,
        d.number_inpatient,
        d.number_emergency,
        d.num_medications,
        d.A1Cresult,
        d.change,
        d.discharge_disposition_id,
        d.diag_1,
        d.readmitted,

        -- Prior inpatent visits: 
        CASE
            WHEN d.number_inpatient >= 3 THEN 30
            WHEN d.number_inpatient = 2 THEN 20
            WHEN d.number_inpatient = 1 THEN 10
            ELSE 0
        END AS points_prior_inpatient,

        -- Prior ER visits: 
        CASE
            WHEN d.number_emergency >= 2 THEN 15
            WHEN d.number_emergency = 1 THEN 8
            ELSE 0
        END AS points_prior_er,

        -- Diagnosis category: 
        CASE
            WHEN d.diag_1 LIKE '250%' THEN 15
            WHEN CAST(LEFT(d.diag_1, 3) AS UNSIGNED) BETWEEN 390 AND 459 THEN 15
            ELSE 0
        END AS points_diagnosis,

        -- Medication burden: 
        CASE
            WHEN d.num_medications > 20 THEN 10
            WHEN d.num_medications BETWEEN 11 AND 20 THEN 5
            ELSE 0
        END AS points_medication_burden,

        -- No A1C test during the stay: 
        CASE WHEN d.A1Cresult = 'None' THEN 10 ELSE 0 END AS points_no_a1c_test,

        -- Medication regimen changed at discharge:
        CASE WHEN d.change = 'Ch' THEN 5 ELSE 0 END AS points_med_change,

-- Older patients: 
        CASE WHEN d.age_midpoint >= 65 THEN 10 ELSE 0 END AS points_age

    FROM diabetic_data_dedup AS d
    WHERE d.diag_1 IS NOT NULL
)
SELECT
    rf.*,
    (points_prior_inpatient + points_prior_er + points_diagnosis
     + points_medication_burden + points_no_a1c_test + points_med_change + points_age)
     AS total_risk_score
FROM risk_factors AS rf;



SELECT
    p.encounter_id,
    p.patient_nbr,
    p.age,
    p.number_inpatient   AS prior_inpatient_visits,
    p.number_emergency   AS prior_er_visits,
    p.num_medications,
    p.A1Cresult,
    p.change             AS med_changed_at_discharge,
    dd.description        AS discharge_disposition,
    p.total_risk_score,
    CASE
        WHEN p.total_risk_score >= 50 THEN 'CALL WITHIN 48 HOURS'
        WHEN p.total_risk_score >= 30 THEN 'CALL WITHIN 1 WEEK'
        ELSE 'ROUTINE FOLLOW-UP'
    END AS outreach_priority
FROM patient_risk_scores AS p
LEFT JOIN discharge_disposition_map AS dd
    ON p.discharge_disposition_id = dd.discharge_disposition_id
ORDER BY p.total_risk_score DESC
LIMIT 100;



SELECT
    CASE
        WHEN total_risk_score >= 50 THEN 'CALL WITHIN 48 HOURS'
        WHEN total_risk_score >= 30 THEN 'CALL WITHIN 1 WEEK'
        ELSE 'ROUTINE FOLLOW-UP'
    END AS outreach_priority,
    COUNT(*) AS total_patients,
    ROUND(SUM(readmitted = '<30') / COUNT(*) * 100, 1) AS actual_readmission_rate_pct
FROM patient_risk_scores
GROUP BY outreach_priority
ORDER BY actual_readmission_rate_pct DESC;
