/*
CREDIT CARD DELINQUENCY EARLY WARNING | 06 - RISK SEGMENTATION BASELINE
Business question: Which repayment-behavior groups account for the most
next-month defaults, considering both default rate and default volume?
Source: dbo.vw_credit_customer_features and dbo.vw_credit_customer_month (script 04).
One row = one customer; the target is next-month default, not a causal outcome.
Read-only; no data is modified.
*/
USE CreditRiskAnalytics;
GO

-- 1. Compare September repayment groups by default rate and share of all defaults.
WITH september AS (
    SELECT
        customer_id,
        status_group,
        CAST(default_next_month AS int) AS default_next_month
    FROM dbo.vw_credit_customer_month
    WHERE month_start = CONVERT(date, '20050901', 112)
)
SELECT
    status_group AS september_status,
    COUNT(*) AS customers,
    SUM(default_next_month) AS default_cases,
    CAST(100.0 * SUM(default_next_month) / NULLIF(COUNT(*), 0) AS decimal(8,2)) AS default_rate_pct,
    CAST(100.0 * SUM(default_next_month)
         / NULLIF(SUM(SUM(default_next_month)) OVER (), 0) AS decimal(8,2)) AS default_contribution_pct
FROM september
GROUP BY status_group
ORDER BY default_cases DESC;
-- Contribution denominator: all 6,636 default cases, not customers in the group.

-- 2. Combine September status and six-month delay frequency to find candidate segments.
WITH customer_segments AS (
    SELECT
        f.customer_id,
        m.status_group AS september_status,
        CASE
            WHEN f.documented_delay_months = 0 THEN '0_DOCUMENTED_DELAY_MONTHS'
            WHEN f.documented_delay_months = 1 THEN '1_DOCUMENTED_DELAY_MONTH'
            ELSE '2PLUS_DOCUMENTED_DELAY_MONTHS'
        END AS delay_history,
        f.default_next_month
    FROM dbo.vw_credit_customer_features AS f
    INNER JOIN dbo.vw_credit_customer_month AS m
        ON f.customer_id = m.customer_id
       AND m.month_start = CONVERT(date, '20050901', 112)
)
SELECT
    september_status,
    delay_history,
    COUNT(*) AS customers,
    SUM(default_next_month) AS default_cases,
    CAST(100.0 * SUM(default_next_month) / NULLIF(COUNT(*), 0) AS decimal(8,2)) AS default_rate_pct,
    CAST(100.0 * SUM(default_next_month)
         / NULLIF(SUM(SUM(default_next_month)) OVER (), 0) AS decimal(8,2)) AS default_contribution_pct
FROM customer_segments
GROUP BY september_status, delay_history
ORDER BY default_cases DESC;
-- '0_DOCUMENTED_DELAY_MONTHS' does NOT mean always paid on time (UNKNOWN exists).

-- 3. Reconcile customer count and default cases after segmentation joins.
SELECT
    (SELECT COUNT(*) FROM dbo.vw_credit_customer_features) AS baseline_customers,
    (SELECT SUM(default_next_month) FROM dbo.vw_credit_customer_features) AS baseline_defaults,
    COUNT(*) AS september_join_rows,
    COUNT(DISTINCT f.customer_id) AS joined_unique_customers,
    SUM(f.default_next_month) AS joined_default_cases
FROM dbo.vw_credit_customer_features AS f
INNER JOIN dbo.vw_credit_customer_month AS m
    ON f.customer_id = m.customer_id
   AND m.month_start = CONVERT(date, '20050901', 112);
-- Expected for this dataset: 30000 | 6636 | 30000 | 30000 | 6636.
GO
