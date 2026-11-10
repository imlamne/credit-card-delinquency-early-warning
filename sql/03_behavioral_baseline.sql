/* Credit Risk UCI | Follow-up DQ & behavior baseline
   SQL Server / SSMS. Read-only; uses dbo.credit_card_raw.
   Interpretation: -1 documented pay duly; 1..9 documented delays;
   -2 and 0 undocumented in UCI official description. */
USE CreditRiskAnalytics;
GO

-- 1) Original counts + outcome reconciliation
SELECT COUNT(*) AS customer_rows,
       COUNT(DISTINCT ID) AS unique_customers,
       SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END) AS default_cases,
       SUM(CASE WHEN DEFAULT_NEXT_MONTH = 0 THEN 1 ELSE 0 END) AS nondefault_cases,
       CAST(100.0 * SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*),0) AS DECIMAL(8,2)) AS default_rate_pct
FROM dbo.credit_card_raw;

-- 2) September status: risk rate AND volume; retain undocumented codes
SELECT PAY_0 AS september_status_raw,
       CASE WHEN PAY_0 = -1 THEN 'DOCUMENTED_PAY_DULY'
            WHEN PAY_0 BETWEEN 1 AND 9 THEN 'DOCUMENTED_DELAY'
            ELSE 'UNDOCUMENTED_STATUS' END AS documentation_group,
       COUNT(*) AS customers,
       SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END) AS default_cases,
       CAST(100.0 * SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*),0) AS DECIMAL(8,2)) AS default_rate_pct
FROM dbo.credit_card_raw
GROUP BY PAY_0
ORDER BY PAY_0;

-- 3) Repayment-status code occurrences across six months
-- These counts are customer-month observations, not unique customers.
WITH status_long AS (
    SELECT r.ID, v.month_label, v.status_code
    FROM dbo.credit_card_raw AS r
    CROSS APPLY (VALUES
       ('2005-04',r.PAY_6),('2005-05',r.PAY_5),('2005-06',r.PAY_4),
       ('2005-07',r.PAY_3),('2005-08',r.PAY_2),('2005-09',r.PAY_0)
    ) v(month_label,status_code)
)
SELECT CASE WHEN status_code = -1 THEN 'DOCUMENTED_PAY_DULY'
            WHEN status_code BETWEEN 1 AND 9 THEN 'DOCUMENTED_DELAY'
            ELSE 'UNDOCUMENTED_STATUS' END AS documentation_group,
       status_code, COUNT(*) AS customer_month_observations,
       COUNT(DISTINCT ID) AS distinct_customers_with_code
FROM status_long
GROUP BY status_code
ORDER BY status_code;

-- 4) Simple six-month candidate indicator (count of documented delay months)
-- Exploratory association, not proof of an intervention effect.
WITH behavior AS (
  SELECT ID, DEFAULT_NEXT_MONTH,
    (CASE WHEN PAY_0 BETWEEN 1 AND 9 THEN 1 ELSE 0 END
    +CASE WHEN PAY_2 BETWEEN 1 AND 9 THEN 1 ELSE 0 END
    +CASE WHEN PAY_3 BETWEEN 1 AND 9 THEN 1 ELSE 0 END
    +CASE WHEN PAY_4 BETWEEN 1 AND 9 THEN 1 ELSE 0 END
    +CASE WHEN PAY_5 BETWEEN 1 AND 9 THEN 1 ELSE 0 END
    +CASE WHEN PAY_6 BETWEEN 1 AND 9 THEN 1 ELSE 0 END) AS documented_delay_months,
    (CASE WHEN PAY_0 IN (-2,0) THEN 1 ELSE 0 END
    +CASE WHEN PAY_2 IN (-2,0) THEN 1 ELSE 0 END
    +CASE WHEN PAY_3 IN (-2,0) THEN 1 ELSE 0 END
    +CASE WHEN PAY_4 IN (-2,0) THEN 1 ELSE 0 END
    +CASE WHEN PAY_5 IN (-2,0) THEN 1 ELSE 0 END
    +CASE WHEN PAY_6 IN (-2,0) THEN 1 ELSE 0 END) AS undocumented_status_months
  FROM dbo.credit_card_raw
)
SELECT documented_delay_months,
       COUNT(*) AS customers,
       SUM(CASE WHEN undocumented_status_months > 0 THEN 1 ELSE 0 END) AS customers_with_any_undocumented_status,
       SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END) AS default_cases,
       CAST(100.0*SUM(CASE WHEN DEFAULT_NEXT_MONTH = 1 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS DECIMAL(8,2)) AS default_rate_pct
FROM behavior
GROUP BY documented_delay_months
ORDER BY documented_delay_months;
