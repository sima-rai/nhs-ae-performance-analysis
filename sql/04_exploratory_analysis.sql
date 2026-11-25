
# ============================================================
# Project: NHS England A&E Performance Analysis
# Script: 04_exploratory_analysis.sql
# Reporting Period: April 2025 - March 2026
# Purpose: Explore national and organisation-level performance
# ============================================================


USE nhs_ae_performance;


# ------------------------------------------------------------
# 1. A&E Attendance Analysis
# ------------------------------------------------------------

# Calculate annual A&E attendances by department
SELECT
    SUM(attendances_type1) AS total_type1_attendances,
    SUM(attendances_type2) AS total_type2_attendances,
    SUM(attendances_other) AS total_other_attendances,

    SUM(
        attendances_type1
        + attendances_type2
        + attendances_other
    ) AS total_ae_attendances

FROM vw_ae_performance_reporting;


# Analyse monthly A&E attendance volumes
SELECT
    reporting_month,
    SUM(attendances_type1) AS type1_attendances,
    SUM(attendances_type2) AS type2_attendances,
    SUM(attendances_other) AS other_attendances,

    SUM(
        attendances_type1
        + attendances_type2
        + attendances_other
    ) AS total_ae_attendances

FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# Normalise monthly attendance volumes by calendar days
SELECT
    reporting_month,

    SUM(
        attendances_type1
        + attendances_type2
        + attendances_other
    ) AS total_ae_attendances,

    DAY(LAST_DAY(reporting_month)) AS days_in_month,

    ROUND(
        SUM(
            attendances_type1
            + attendances_type2
            + attendances_other
        ) / DAY(LAST_DAY(reporting_month)),
        0
    ) AS average_daily_attendances

FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# ------------------------------------------------------------
# 2. Four-Hour Performance Analysis
# ------------------------------------------------------------

# Calculate annual four-hour performance by department
SELECT
    ROUND(
        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100,
        2
    ) AS type1_within_4hrs_pct,

    ROUND(
        (SUM(attendances_type2) - SUM(over4hrs_type2))
        / NULLIF(SUM(attendances_type2), 0) * 100,
        2
    ) AS type2_within_4hrs_pct,

    ROUND(
        (SUM(attendances_other) - SUM(over4hrs_other))
        / NULLIF(SUM(attendances_other), 0) * 100,
        2
    ) AS other_within_4hrs_pct

FROM vw_ae_performance_reporting;


# Calculate annual four-hour performance across all departments
WITH annual_performance AS (
    SELECT
        SUM(
            attendances_type1
            + attendances_type2
            + attendances_other
        ) AS total_attendances,

        SUM(
            over4hrs_type1
            + over4hrs_type2
            + over4hrs_other
        ) AS total_over4hrs

    FROM vw_ae_performance_reporting
)
SELECT
    total_attendances,
    total_over4hrs,
    total_attendances - total_over4hrs AS total_within4hrs,

    ROUND(
        (total_attendances - total_over4hrs)
        / NULLIF(total_attendances, 0) * 100,
        2
    ) AS all_departments_within_4hrs_pct

FROM annual_performance;


# Analyse monthly Type 1 four-hour performance
SELECT
    reporting_month,
    SUM(attendances_type1) AS total_type1_attendances,
    SUM(over4hrs_type1) AS total_type1_over4hrs,

    SUM(attendances_type1) - SUM(over4hrs_type1)
        AS total_type1_within4hrs,

    ROUND(
        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100,
        2
    ) AS type1_within_4hrs_pct

FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# ------------------------------------------------------------
# 3. Decision-to-Admit Waiting Time Analysis
# ------------------------------------------------------------

# Calculate annual DTA waiting-time volumes
SELECT
    SUM(dta_wait_4_12hrs) AS total_dta_waits_4_12hrs,
    SUM(dta_wait_12plus_hrs) AS total_dta_waits_12plus_hrs
FROM vw_ae_performance_reporting;


# Analyse monthly DTA waiting-time volumes
SELECT
    reporting_month,
    SUM(dta_wait_4_12hrs) AS dta_waits_4_12hrs,
    SUM(dta_wait_12plus_hrs) AS dta_waits_12plus_hrs
FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# ------------------------------------------------------------
# 4. Emergency Admissions Analysis
# ------------------------------------------------------------

# Calculate annual emergency admissions via A&E
SELECT
    SUM(admissions_type1) AS total_type1_admissions,
    SUM(admissions_type2) AS total_type2_admissions,
    SUM(admissions_other) AS total_other_ae_admissions,

    SUM(
        admissions_type1
        + admissions_type2
        + admissions_other
    ) AS total_emergency_admissions_via_ae

FROM vw_ae_performance_reporting;


# Analyse monthly emergency admissions via A&E
SELECT
    reporting_month,

    SUM(
        admissions_type1
        + admissions_type2
        + admissions_other
    ) AS emergency_admissions_via_ae

FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# Compare monthly emergency admissions with long DTA waits
SELECT
    reporting_month,

    SUM(
        admissions_type1
        + admissions_type2
        + admissions_other
    ) AS emergency_admissions_via_ae,

    SUM(dta_wait_12plus_hrs) AS dta_waits_12plus_hrs

FROM vw_ae_performance_reporting
GROUP BY reporting_month
ORDER BY reporting_month;


# ------------------------------------------------------------
# 5. Organisation Performance Analysis
# ------------------------------------------------------------

# Calculate annual Type 1 performance for eligible organisations
SELECT
    org_code,
    org_name_standardised,
    SUM(attendances_type1) AS total_type1_attendances,
    SUM(over4hrs_type1) AS total_type1_over4hrs,

    ROUND(
        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100,
        2
    ) AS type1_within_4hrs_pct

FROM vw_ae_performance_reporting
GROUP BY
    org_code,
    org_name_standardised
HAVING SUM(attendances_type1) >= 10000
ORDER BY
    type1_within_4hrs_pct ASC,
    org_code;


# Calculate summary statistics for eligible organisations
WITH organisation_performance AS (
    SELECT
        org_code,

        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100
            AS performance_pct

    FROM vw_ae_performance_reporting
    GROUP BY org_code
    HAVING SUM(attendances_type1) >= 10000
),
ranked_performance AS (
    SELECT
        org_code,
        performance_pct,

        ROW_NUMBER() OVER (
            ORDER BY performance_pct, org_code
        ) AS row_num,

        COUNT(*) OVER () AS total_organisations

    FROM organisation_performance
)
SELECT
    COUNT(*) AS eligible_organisations,
    ROUND(AVG(performance_pct), 2) AS mean_performance_pct,

    ROUND(
        AVG(
            CASE
                WHEN row_num IN (
                    FLOOR((total_organisations + 1) / 2),
                    FLOOR((total_organisations + 2) / 2)
                )
                THEN performance_pct
            END
        ),
        2
    ) AS median_performance_pct,

    ROUND(MIN(performance_pct), 2) AS minimum_performance_pct,
    ROUND(MAX(performance_pct), 2) AS maximum_performance_pct,

    ROUND(
        MAX(performance_pct) - MIN(performance_pct),
        2
    ) AS performance_range_pp

FROM ranked_performance;


# Identify the 10 lowest-performing eligible organisations
SELECT
    org_code,
    org_name_standardised,
    SUM(attendances_type1) AS total_type1_attendances,

    ROUND(
        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100,
        2
    ) AS type1_within_4hrs_pct

FROM vw_ae_performance_reporting
GROUP BY
    org_code,
    org_name_standardised
HAVING SUM(attendances_type1) >= 10000
ORDER BY
    (SUM(attendances_type1) - SUM(over4hrs_type1))
    / NULLIF(SUM(attendances_type1), 0) ASC,
    org_code
LIMIT 10;


# Identify the 10 highest-performing eligible organisations
SELECT
    org_code,
    org_name_standardised,
    SUM(attendances_type1) AS total_type1_attendances,

    ROUND(
        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100,
        2
    ) AS type1_within_4hrs_pct

FROM vw_ae_performance_reporting
GROUP BY
    org_code,
    org_name_standardised
HAVING SUM(attendances_type1) >= 10000
ORDER BY
    (SUM(attendances_type1) - SUM(over4hrs_type1))
    / NULLIF(SUM(attendances_type1), 0) DESC,
    org_code
LIMIT 10;


# ------------------------------------------------------------
# 6. Organisation Benchmarking
# ------------------------------------------------------------

# Compare Mid Cheshire's monthly performance against national performance
WITH national_performance AS (
    SELECT
        reporting_month,

        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100
            AS national_performance_pct

    FROM vw_ae_performance_reporting
    GROUP BY reporting_month
),
organisation_performance AS (
    SELECT
        reporting_month,
        org_code,
        org_name_standardised,

        (SUM(attendances_type1) - SUM(over4hrs_type1))
        / NULLIF(SUM(attendances_type1), 0) * 100
            AS organisation_performance_pct

    FROM vw_ae_performance_reporting
    WHERE org_code = 'RBT'
    GROUP BY
        reporting_month,
        org_code,
        org_name_standardised
)
SELECT
    o.reporting_month,
    o.org_code,
    o.org_name_standardised,

    ROUND(o.organisation_performance_pct, 2)
        AS organisation_performance_pct,

    ROUND(n.national_performance_pct, 2)
        AS national_performance_pct,

    ROUND(
        o.organisation_performance_pct
        - n.national_performance_pct,
        2
    ) AS performance_gap_pp

FROM organisation_performance AS o
INNER JOIN national_performance AS n
    ON o.reporting_month = n.reporting_month
ORDER BY o.reporting_month;
