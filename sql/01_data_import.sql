
# ============================================================
# Project: NHS England A&E Performance Analysis
# Script: 01_data_import.sql
# Reporting Period: April 2025 - March 2026
# Purpose: Database setup, data import and initial inspection
# ============================================================


# Create the project database
CREATE DATABASE IF NOT EXISTS nhs_ae_performance;


# Select the project database
USE nhs_ae_performance;


# ------------------------------------------------------------
# Manual Data Import
# ------------------------------------------------------------
# Import the combined NHS A&E CSV dataset using the
# MySQL Workbench Table Data Import Wizard.
#
# 1. Right-click the nhs_ae_performance schema.
# 2. Select Table Data Import Wizard.
# 3. Select the combined CSV dataset.
# 4. Create a new table named ae_attendances_staging.
# 5. Review column mappings and data types.
# 6. Complete the import.
#
# Skip the import if the staging table already exists
# and contains the complete dataset.
# ------------------------------------------------------------


# Preview the imported data
SELECT *
FROM ae_attendances_staging
LIMIT 10;


# Verify the total number of imported records
SELECT
    COUNT(*) AS imported_rows
FROM ae_attendances_staging;


# Inspect column names and data types
DESCRIBE ae_attendances_staging;


# Inspect the staging table definition
SHOW CREATE TABLE ae_attendances_staging;
