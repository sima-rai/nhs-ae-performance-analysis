
# ============================================================
# Project: NHS England A&E Performance Analysis
# Script: 05_powerbi_data_prep.sql
# Reporting Period: April 2025 - March 2026
# Purpose: Prepare and validate data sources for Power BI
# ============================================================


USE nhs_ae_performance;


# ------------------------------------------------------------
# 1. Fact Table Preparation
# ------------------------------------------------------------

# Retrieve the 20 columns used in FactAEPerformance
SELECT
    org_code,
    reporting_month,

    attendances_type1,
    attendances_type2,
    attendances_other,

    booked_attendances_type1,
    booked_attendances_type2,
    booked_attendances_other,

    over4hrs_type1,
    over4hrs_type2,
    over4hrs_other,

    over4hrs_booked_type1,
    over4hrs_booked_type2,
    over4hrs_booked_other,

    dta_wait_4_12hrs,
    dta_wait_12plus_hrs,

    admissions_type1,
    admissions_type2,
    admissions_other,
    other_emergency_admissions

FROM vw_ae_performance_reporting;


# ------------------------------------------------------------
# 2. Organisation Dimension Preparation
# ------------------------------------------------------------

# Retrieve the columns used in DimOrganisation
SELECT
    org_code,
    org_name_standardised
FROM vw_ae_organisation_names
ORDER BY org_code;


# ------------------------------------------------------------
# 3. Data Model Validation
# ------------------------------------------------------------

# Verify fact table granularity and reporting period
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT org_code, reporting_month) AS unique_org_months,
    COUNT(DISTINCT org_code) AS unique_organisations,
    COUNT(DISTINCT reporting_month) AS reporting_months,
    MIN(reporting_month) AS first_reporting_month,
    MAX(reporting_month) AS last_reporting_month
FROM vw_ae_performance_reporting;


# Verify organisation dimension key uniqueness
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT org_code) AS unique_org_codes
FROM vw_ae_organisation_names;


# Check for fact records without a matching organisation
SELECT
    f.org_code,
    f.reporting_month
FROM vw_ae_performance_reporting AS f
LEFT JOIN vw_ae_organisation_names AS d
    ON f.org_code = d.org_code
WHERE d.org_code IS NULL;


# ------------------------------------------------------------
# 4. KPI Reference Values
# ------------------------------------------------------------

# Calculate reference values for the five core Power BI KPIs
WITH annual_totals AS (
    SELECT
        SUM(
            attendances_type1
            + attendances_type2
            + attendances_other
        ) AS total_ae_attendances,

        SUM(attendances_type1) AS total_type1_attendances,

        SUM(over4hrs_type1) AS total_type1_over4hrs,

        SUM(
            over4hrs_type1
            + over4hrs_type2
            + over4hrs_other
        ) AS total_ae_over4hrs,

        SUM(dta_wait_12plus_hrs) AS dta_waits_12plus_hrs,

        SUM(
            admissions_type1
            + admissions_type2
            + admissions_other
        ) AS emergency_admissions_via_ae

    FROM vw_ae_performance_reporting
)
SELECT
    total_ae_attendances,

    ROUND(
        (total_type1_attendances - total_type1_over4hrs)
        / NULLIF(total_type1_attendances, 0) * 100,
        2
    ) AS type1_within_4hrs_pct,

    ROUND(
        (total_ae_attendances - total_ae_over4hrs)
        / NULLIF(total_ae_attendances, 0) * 100,
        2
    ) AS all_departments_within_4hrs_pct,

    dta_waits_12plus_hrs,
    emergency_admissions_via_ae

FROM annual_totals;


# ------------------------------------------------------------
# 5. Power BI Connection and Model Configuration
# ------------------------------------------------------------
#
# Connection:
#   Source: MySQL Database
#   Server: localhost
#   Database: nhs_ae_performance
#   Connection mode: Import
#
# Fact table:
#   Source: vw_ae_performance_reporting
#   Power BI table: FactAEPerformance
#   Retain organisation code, reporting month and
#   all 18 numerical columns in Power Query.
#
# Organisation dimension:
#   Source: vw_ae_organisation_names
#   Power BI table: DimOrganisation
#
# Date dimension:
#   Created directly in Power BI using DAX CALENDAR.
#   Date range: 2025-04-01 to 2026-03-31.
#
# Relationships:
#   DimOrganisation[org_code] (1)
#       -> FactAEPerformance[org_code] (*)
#
#   DimDate[Date] (1)
#       -> FactAEPerformance[reporting_month] (*)
#
# Both relationships are active, one-to-many
# and use single-direction filtering.
#
# Security:
#   Use a dedicated read-only MySQL account.
#   Grant SELECT permissions on the project database.
#   Do not store database passwords in SQL scripts
#   or publish credentials to GitHub.
# ------------------------------------------------------------
