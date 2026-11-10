/*
00 | DATABASE SETUP AND RAW TABLE SCHEMA
Purpose: Recreate the SQL Server input structure used by scripts 01 through 07.
Dataset: UCI Default of Credit Card Clients, 30,000 rows, April to September 2005.
IMPORTANT: This script DOES NOT import any records or replace an existing table.
Use the CSV import instructions in README.md after creating the table.
*/

-- 1. Create the project database only if it does not exist.
IF DB_ID(N'CreditRiskAnalytics') IS NULL
    CREATE DATABASE CreditRiskAnalytics;
GO
USE CreditRiskAnalytics;
GO

-- 2. Create the raw table if absent. Keep the original source values unchanged.
-- ID is INT (not SMALLINT) because the dataset includes customer ID 30000.
IF OBJECT_ID(N'dbo.credit_card_raw', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.credit_card_raw (
        ID INT NOT NULL,
        LIMIT_BAL INT NOT NULL,
        SEX TINYINT NOT NULL,
        EDUCATION TINYINT NOT NULL,
        MARRIAGE TINYINT NOT NULL,
        AGE TINYINT NOT NULL,
        PAY_0 SMALLINT NOT NULL,
        PAY_2 SMALLINT NOT NULL,
        PAY_3 SMALLINT NOT NULL,
        PAY_4 SMALLINT NOT NULL,
        PAY_5 SMALLINT NOT NULL,
        PAY_6 SMALLINT NOT NULL,
        BILL_AMT1 INT NOT NULL,
        BILL_AMT2 INT NOT NULL,
        BILL_AMT3 INT NOT NULL,
        BILL_AMT4 INT NOT NULL,
        BILL_AMT5 INT NOT NULL,
        BILL_AMT6 INT NOT NULL,
        PAY_AMT1 INT NOT NULL,
        PAY_AMT2 INT NOT NULL,
        PAY_AMT3 INT NOT NULL,
        PAY_AMT4 INT NOT NULL,
        PAY_AMT5 INT NOT NULL,
        PAY_AMT6 INT NOT NULL,
        DEFAULT_NEXT_MONTH BIT NOT NULL
    );
END;
GO

-- 3. Import the clean 25-column CSV after exporting it from the UCI XLS.
-- Edit the absolute path below, REMOVE the comment markers, and run only this block.
-- SQL Server 2017+ CSV syntax; the SQL Server service must be able to read the path.
-- Do not run the same BULK INSERT twice without first checking the row count.
/*
BULK INSERT dbo.credit_card_raw
FROM 'C:\Data\uci_credit_card_clients_clean_header.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    CODEPAGE = '65001',
    TABLOCK
);
*/

-- 4. Verify the input count. Expected: 30000 rows after import.
SELECT COUNT(*) AS raw_customer_rows,
       COUNT(DISTINCT ID) AS unique_customer_ids
FROM dbo.credit_card_raw;
GO

-- Next: run 01_raw_data_validation.sql, then scripts 02 through 07.
