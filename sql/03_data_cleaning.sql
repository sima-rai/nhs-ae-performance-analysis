
# ============================================================
# Project: NHS England A&E Performance Analysis
# Script: 03_data_cleaning.sql
# Reporting Period: April 2025 - March 2026
# Purpose: Data cleaning, transformation and standardisation
# ============================================================


USE nhs_ae_performance;


# ------------------------------------------------------------
# 1. Base Organisation View
# ------------------------------------------------------------

# Rename columns, convert reporting dates and exclude national TOTAL records
CREATE OR REPLACE VIEW vw_ae_organisations_base AS
SELECT
    `Org Code` AS org_code,
    `Org name` AS org_name,
    `Parent Org` AS parent_org,
    Period AS original_period,

    STR_TO_DATE(
        CONCAT('01-', REPLACE(Period, 'MSitAE-', '')),
        '%d-%M-%Y'
    ) AS reporting_month

FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL';


# Validate record counts and reporting dates
SELECT
    COUNT(*) AS total_records,
    SUM(reporting_month IS NULL) AS missing_dates,
    COUNT(DISTINCT reporting_month) AS reporting_months
FROM vw_ae_organisations_base;


# ------------------------------------------------------------
# 2. Cleaned Performance View
# ------------------------------------------------------------

# Combine cleaned organisation information with all 18 numerical measures
CREATE OR REPLACE VIEW vw_ae_performance_clean AS
SELECT
    b.org_code,
    b.org_name,
    b.parent_org,
    b.original_period,
    b.reporting_month,

    s.`A&E attendances Type 1` AS attendances_type1,
    s.`A&E attendances Type 2` AS attendances_type2,
    s.`A&E attendances Other A&E Department` AS attendances_other,

    s.`A&E attendances Booked Appointments Type 1` AS booked_attendances_type1,
    s.`A&E attendances Booked Appointments Type 2` AS booked_attendances_type2,
    s.`A&E attendances Booked Appointments Other Department` AS booked_attendances_other,

    s.`Attendances over 4hrs Type 1` AS over4hrs_type1,
    s.`Attendances over 4hrs Type 2` AS over4hrs_type2,
    s.`Attendances over 4hrs Other Department` AS over4hrs_other,

    s.`Attendances over 4hrs Booked Appointments Type 1` AS over4hrs_booked_type1,
    s.`Attendances over 4hrs Booked Appointments Type 2` AS over4hrs_booked_type2,
    s.`Attendances over 4hrs Booked Appointments Other Department` AS over4hrs_booked_other,

    s.`Patients who have waited 4-12 hs from DTA to admission` AS dta_wait_4_12hrs,
    s.`Patients who have waited 12+ hrs from DTA to admission` AS dta_wait_12plus_hrs,

    s.`Emergency admissions via A&E - Type 1` AS admissions_type1,
    s.`Emergency admissions via A&E - Type 2` AS admissions_type2,
    s.`Emergency admissions via A&E - Other A&E department` AS admissions_other,
    s.`Other emergency admissions` AS other_emergency_admissions

FROM vw_ae_organisations_base AS b
INNER JOIN ae_attendances_staging AS s
    ON b.org_code = s.`Org Code`
    AND b.original_period = s.Period;


# Validate record counts and organisation-month uniqueness
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT org_code, reporting_month) AS unique_org_months,
    COUNT(DISTINCT reporting_month) AS reporting_months
FROM vw_ae_performance_clean;


# Compare Type 1 attendance totals before and after transformation
SELECT
    (
        SELECT SUM(`A&E attendances Type 1`)
        FROM ae_attendances_staging
        WHERE `Org Code` <> 'TOTAL'
    ) AS staging_total,

    (
        SELECT SUM(attendances_type1)
        FROM vw_ae_performance_clean
    ) AS cleaned_total;


# Verify that all 18 numerical measures match the original staging records
SELECT
    COUNT(*) AS records_checked,
    SUM(
        NOT (
            s.`A&E attendances Type 1` <=> c.attendances_type1
            AND s.`A&E attendances Type 2` <=> c.attendances_type2
            AND s.`A&E attendances Other A&E Department` <=> c.attendances_other
            AND s.`A&E attendances Booked Appointments Type 1` <=> c.booked_attendances_type1
            AND s.`A&E attendances Booked Appointments Type 2` <=> c.booked_attendances_type2
            AND s.`A&E attendances Booked Appointments Other Department` <=> c.booked_attendances_other
            AND s.`Attendances over 4hrs Type 1` <=> c.over4hrs_type1
            AND s.`Attendances over 4hrs Type 2` <=> c.over4hrs_type2
            AND s.`Attendances over 4hrs Other Department` <=> c.over4hrs_other
            AND s.`Attendances over 4hrs Booked Appointments Type 1` <=> c.over4hrs_booked_type1
            AND s.`Attendances over 4hrs Booked Appointments Type 2` <=> c.over4hrs_booked_type2
            AND s.`Attendances over 4hrs Booked Appointments Other Department` <=> c.over4hrs_booked_other
            AND s.`Patients who have waited 4-12 hs from DTA to admission` <=> c.dta_wait_4_12hrs
            AND s.`Patients who have waited 12+ hrs from DTA to admission` <=> c.dta_wait_12plus_hrs
            AND s.`Emergency admissions via A&E - Type 1` <=> c.admissions_type1
            AND s.`Emergency admissions via A&E - Type 2` <=> c.admissions_type2
            AND s.`Emergency admissions via A&E - Other A&E department` <=> c.admissions_other
            AND s.`Other emergency admissions` <=> c.other_emergency_admissions
        )
    ) AS records_with_mismatches
FROM vw_ae_performance_clean AS c
INNER JOIN ae_attendances_staging AS s
    ON c.org_code = s.`Org Code`
    AND c.original_period = s.Period;


# ------------------------------------------------------------
# 3. Organisation Name Standardisation
# ------------------------------------------------------------

# Identify organisation codes associated with multiple names
SELECT
    org_code,
    COUNT(DISTINCT org_name) AS distinct_names,
    GROUP_CONCAT(
        DISTINCT org_name
        ORDER BY org_name
        SEPARATOR ' | '
    ) AS organisation_names
FROM vw_ae_performance_clean
GROUP BY org_code
HAVING COUNT(DISTINCT org_name) > 1
ORDER BY org_code;


# Identify the latest recorded names for organisations with name variations
SELECT
    org_code,
    org_name AS latest_org_name,
    reporting_month
FROM (
    SELECT
        org_code,
        org_name,
        reporting_month,
        ROW_NUMBER() OVER (
            PARTITION BY org_code
            ORDER BY reporting_month DESC
        ) AS row_num
    FROM vw_ae_performance_clean
    WHERE org_code IN ('A5D4Q', 'RA2', 'RRF', 'RWH')
) AS ranked_names
WHERE row_num = 1
ORDER BY org_code;


# Create a lookup view using the latest recorded name for each organisation
CREATE OR REPLACE VIEW vw_ae_organisation_names AS
SELECT
    org_code,
    org_name AS org_name_standardised
FROM (
    SELECT
        org_code,
        org_name,
        ROW_NUMBER() OVER (
            PARTITION BY org_code
            ORDER BY reporting_month DESC
        ) AS row_num
    FROM vw_ae_organisations_base
) AS ranked_names
WHERE row_num = 1;


# Validate organisation code uniqueness and standardised name completeness
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT org_code) AS unique_org_codes,
    SUM(org_name_standardised IS NULL) AS missing_names
FROM vw_ae_organisation_names;


# ------------------------------------------------------------
# 4. Final Reporting View
# ------------------------------------------------------------

# Combine cleaned performance records with standardised organisation names
CREATE OR REPLACE VIEW vw_ae_performance_reporting AS
SELECT
    c.*,
    n.org_name_standardised
FROM vw_ae_performance_clean AS c
INNER JOIN vw_ae_organisation_names AS n
    ON c.org_code = n.org_code;


# Validate the final reporting dataset
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT org_code, reporting_month) AS unique_org_months,
    COUNT(DISTINCT org_code) AS total_organisations,
    COUNT(DISTINCT reporting_month) AS reporting_months,
    SUM(org_name_standardised IS NULL) AS missing_names
FROM vw_ae_performance_reporting;


# Preview the final analysis-ready dataset
SELECT *
FROM vw_ae_performance_reporting
LIMIT 10;
