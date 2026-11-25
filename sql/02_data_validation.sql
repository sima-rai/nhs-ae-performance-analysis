
# ============================================================
# Project: NHS England A&E Performance Analysis
# Script: 02_data_validation.sql
# Reporting Period: April 2025 - March 2026
# Purpose: Validate the quality and consistency of raw data
# ============================================================


USE nhs_ae_performance;


# ------------------------------------------------------------
# 1. Dataset Completeness
# ------------------------------------------------------------

# Verify the total number of imported records
SELECT
    COUNT(*) AS total_imported_rows
FROM ae_attendances_staging;


# Inspect reporting periods and monthly record counts
SELECT
    Period,
    COUNT(*) AS total_records,
    COUNT(DISTINCT `Org Code`) AS distinct_org_codes
FROM ae_attendances_staging
GROUP BY Period
ORDER BY Period;


# ------------------------------------------------------------
# 2. National Aggregate Records
# ------------------------------------------------------------

# Identify national aggregate records
SELECT
    Period,
    `Org Code`,
    `Org name`
FROM ae_attendances_staging
WHERE `Org Code` = 'TOTAL'
ORDER BY Period;


# Compare national aggregate and organisation record counts
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN `Org Code` = 'TOTAL' THEN 1 ELSE 0 END)
        AS national_aggregate_records,
    SUM(CASE WHEN `Org Code` <> 'TOTAL' THEN 1 ELSE 0 END)
        AS organisation_records
FROM ae_attendances_staging;


# Count unique reporting organisations and periods
SELECT
    COUNT(DISTINCT `Org Code`) AS unique_organisations,
    COUNT(DISTINCT Period) AS reporting_periods
FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL';


# ------------------------------------------------------------
# 3. Duplicate Detection
# ------------------------------------------------------------

# Check for duplicate organisation-month combinations
SELECT
    Period,
    `Org Code`,
    COUNT(*) AS duplicate_count
FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL'
GROUP BY
    Period,
    `Org Code`
HAVING COUNT(*) > 1;


# ------------------------------------------------------------
# 4. Missing Metadata
# ------------------------------------------------------------

# Check for missing or empty organisation codes
SELECT
    Period,
    `Org Code`,
    `Org name`
FROM ae_attendances_staging
WHERE `Org Code` IS NULL
    OR TRIM(`Org Code`) = '';


# Check for missing or empty organisation names
SELECT
    Period,
    `Org Code`,
    `Org name`
FROM ae_attendances_staging
WHERE `Org name` IS NULL
    OR TRIM(`Org name`) = '';


# ------------------------------------------------------------
# 5. Numerical Completeness
# ------------------------------------------------------------

# Check for missing values across all 18 numerical measures
SELECT
    COUNT(*) AS total_organisation_records,

    COUNT(*) - COUNT(`A&E attendances Type 1`)
        AS missing_type1,

    COUNT(*) - COUNT(`A&E attendances Type 2`)
        AS missing_type2,

    COUNT(*) - COUNT(`A&E attendances Other A&E Department`)
        AS missing_other_ae,

    COUNT(*) - COUNT(`A&E attendances Booked Appointments Type 1`)
        AS missing_booked_type1,

    COUNT(*) - COUNT(`A&E attendances Booked Appointments Type 2`)
        AS missing_booked_type2,

    COUNT(*) - COUNT(`A&E attendances Booked Appointments Other Department`)
        AS missing_booked_other,

    COUNT(*) - COUNT(`Attendances over 4hrs Type 1`)
        AS missing_over4_type1,

    COUNT(*) - COUNT(`Attendances over 4hrs Type 2`)
        AS missing_over4_type2,

    COUNT(*) - COUNT(`Attendances over 4hrs Other Department`)
        AS missing_over4_other,

    COUNT(*) - COUNT(`Attendances over 4hrs Booked Appointments Type 1`)
        AS missing_over4_booked_type1,

    COUNT(*) - COUNT(`Attendances over 4hrs Booked Appointments Type 2`)
        AS missing_over4_booked_type2,

    COUNT(*) - COUNT(`Attendances over 4hrs Booked Appointments Other Department`)
        AS missing_over4_booked_other,

    COUNT(*) - COUNT(`Patients who have waited 4-12 hs from DTA to admission`)
        AS missing_dta_4_12,

    COUNT(*) - COUNT(`Patients who have waited 12+ hrs from DTA to admission`)
        AS missing_dta_12plus,

    COUNT(*) - COUNT(`Emergency admissions via A&E - Type 1`)
        AS missing_admissions_type1,

    COUNT(*) - COUNT(`Emergency admissions via A&E - Type 2`)
        AS missing_admissions_type2,

    COUNT(*) - COUNT(`Emergency admissions via A&E - Other A&E department`)
        AS missing_admissions_other_ae,

    COUNT(*) - COUNT(`Other emergency admissions`)
        AS missing_other_emergency_admissions

FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL';


# ------------------------------------------------------------
# 6. Numerical Validity
# ------------------------------------------------------------

# Check for negative values across all 18 numerical measures
SELECT
    Period,
    `Org Code`,
    `Org name`
FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL'
    AND (
        `A&E attendances Type 1` < 0
        OR `A&E attendances Type 2` < 0
        OR `A&E attendances Other A&E Department` < 0
        OR `A&E attendances Booked Appointments Type 1` < 0
        OR `A&E attendances Booked Appointments Type 2` < 0
        OR `A&E attendances Booked Appointments Other Department` < 0
        OR `Attendances over 4hrs Type 1` < 0
        OR `Attendances over 4hrs Type 2` < 0
        OR `Attendances over 4hrs Other Department` < 0
        OR `Attendances over 4hrs Booked Appointments Type 1` < 0
        OR `Attendances over 4hrs Booked Appointments Type 2` < 0
        OR `Attendances over 4hrs Booked Appointments Other Department` < 0
        OR `Patients who have waited 4-12 hs from DTA to admission` < 0
        OR `Patients who have waited 12+ hrs from DTA to admission` < 0
        OR `Emergency admissions via A&E - Type 1` < 0
        OR `Emergency admissions via A&E - Type 2` < 0
        OR `Emergency admissions via A&E - Other A&E department` < 0
        OR `Other emergency admissions` < 0
    );


# ------------------------------------------------------------
# 7. Logical Consistency
# ------------------------------------------------------------

# Check whether over-four-hour attendances exceed corresponding attendances
SELECT
    Period,
    `Org Code`,
    `Org name`
FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL'
    AND (
        `Attendances over 4hrs Type 1` >
            `A&E attendances Type 1`

        OR `Attendances over 4hrs Type 2` >
            `A&E attendances Type 2`

        OR `Attendances over 4hrs Other Department` >
            `A&E attendances Other A&E Department`

        OR `Attendances over 4hrs Booked Appointments Type 1` >
            `A&E attendances Booked Appointments Type 1`

        OR `Attendances over 4hrs Booked Appointments Type 2` >
            `A&E attendances Booked Appointments Type 2`

        OR `Attendances over 4hrs Booked Appointments Other Department` >
            `A&E attendances Booked Appointments Other Department`
    );


# ------------------------------------------------------------
# 8. Data Profiling
# ------------------------------------------------------------

# Identify records with positive DTA waits and Type 1 admissions
SELECT
    COUNT(*) AS total_records,

    SUM(
        CASE
            WHEN `Patients who have waited 4-12 hs from DTA to admission` > 0
            THEN 1
            ELSE 0
        END
    ) AS records_with_dta_4_12,

    SUM(
        CASE
            WHEN `Patients who have waited 12+ hrs from DTA to admission` > 0
            THEN 1
            ELSE 0
        END
    ) AS records_with_dta_12plus,

    SUM(
        CASE
            WHEN `Emergency admissions via A&E - Type 1` > 0
            THEN 1
            ELSE 0
        END
    ) AS records_with_type1_admissions

FROM ae_attendances_staging
WHERE `Org Code` <> 'TOTAL';


# ------------------------------------------------------------
# 9. Source Reconciliation
# ------------------------------------------------------------

# Calculate April Type 1 attendances for source comparison
SELECT
    SUM(`A&E attendances Type 1`) AS april_type1_attendances
FROM ae_attendances_staging
WHERE Period = 'MSitAE-APRIL-2025'
    AND `Org Code` <> 'TOTAL';


# Reconcile annual Type 1 attendance totals
SELECT
    organisation_total,
    national_total,
    organisation_total - national_total AS difference
FROM (
    SELECT
        SUM(
            CASE
                WHEN `Org Code` <> 'TOTAL'
                THEN `A&E attendances Type 1`
                ELSE 0
            END
        ) AS organisation_total,

        SUM(
            CASE
                WHEN `Org Code` = 'TOTAL'
                THEN `A&E attendances Type 1`
                ELSE 0
            END
        ) AS national_total

    FROM ae_attendances_staging
) AS reconciliation;
