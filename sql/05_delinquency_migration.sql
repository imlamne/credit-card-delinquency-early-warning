/*
CREDIT CARD DELINQUENCY EARLY WARNING | 05 - MONTHLY REPAYMENT STATUS TRANSITIONS
Business question: How do repayment statuses change across months, and how
is the most recent change associated with next-month default?
Prerequisite: Run script 04 (vw_credit_customer_month).
Read-only: no source data or views are modified.
Note: Status transitions compare three project-defined groups (PAY_DULY,
DELAY, UNKNOWN), not exact delay severity or Days Past Due (DPD) buckets.
UNKNOWN has codes whose business meaning has not been confirmed.
*/
USE CreditRiskAnalytics;
GO

-- 1. Compare status groups across adjacent months (not raw-code severity).
-- DELAY -> DELAY includes changes such as raw code 1 -> 2 or 2 -> 1.
WITH monthly_changes AS (
    SELECT
        customer_id, month_start, status_group, repayment_status_raw,
        LAG(status_group) OVER (PARTITION BY customer_id ORDER BY month_start) AS prior_status_group
    FROM dbo.vw_credit_customer_month
)
SELECT
    prior_status_group AS from_status,
    status_group AS to_status,
    COUNT(*) AS transitions,
    CAST(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY prior_status_group), 0)
         AS decimal(8,2)) AS pct_of_from_status
FROM monthly_changes
WHERE prior_status_group IS NOT NULL
GROUP BY prior_status_group, status_group
ORDER BY prior_status_group, status_group;
-- Expected: 150,000 transitions (30,000 customers x 5 adjacent month pairs).
-- pct_of_from_status uses each FROM-status as denominator (rows sum to 100% per FROM-status).

-- 2. Compare Aug to Sep status group pairs with next-month default rates.
WITH latest_change AS (
    SELECT
        customer_id, month_start, status_group,
        CAST(default_next_month AS int) AS default_next_month,
        LAG(status_group) OVER (PARTITION BY customer_id ORDER BY month_start) AS prior_status_group
    FROM dbo.vw_credit_customer_month
), aug_sep AS (
    SELECT
        customer_id, default_next_month,
        CASE
            WHEN prior_status_group = 'PAY_DULY' AND status_group = 'DELAY'
                THEN 'ENTERED_DELAY_FROM_PAY_DULY'
            WHEN prior_status_group = 'DELAY' AND status_group = 'DELAY'
                THEN 'REMAINED_IN_DELAY'
            WHEN prior_status_group = 'DELAY' AND status_group = 'PAY_DULY'
                THEN 'EXITED_DELAY_TO_PAY_DULY'
            WHEN prior_status_group = 'PAY_DULY' AND status_group = 'PAY_DULY'
                THEN 'REMAINED_PAY_DULY'
            ELSE 'UNKNOWN_INVOLVED'
        END AS migration_group
    FROM latest_change
    WHERE month_start = CONVERT(date, '20050901', 112)
)
SELECT
    migration_group,
    COUNT(*) AS customers,
    SUM(default_next_month) AS default_cases,
    CAST(100.0 * SUM(default_next_month) / NULLIF(COUNT(*), 0)
         AS decimal(8,2)) AS default_rate_pct
FROM aug_sep
GROUP BY migration_group
ORDER BY default_rate_pct DESC;
-- Expected: 30,000 customers and 6,636 defaults across all groups.
-- UNKNOWN_INVOLVED means at least one of the two months is UNKNOWN;
-- do not interpret it as improvement or deterioration.

-- 3. Reconciliation: ensure exactly five transitions/customer and valid Aug-Sep totals.
WITH status_sequence AS (
    SELECT
        customer_id, month_start,
        LAG(month_start) OVER (PARTITION BY customer_id ORDER BY month_start) AS prior_month,
        CAST(default_next_month AS int) AS default_next_month
    FROM dbo.vw_credit_customer_month
)
SELECT
    COUNT(*) AS total_customer_month_rows,
    SUM(CASE WHEN prior_month IS NOT NULL THEN 1 ELSE 0 END) AS total_transitions,
    SUM(CASE WHEN month_start = CONVERT(date, '20050901', 112) THEN 1 ELSE 0 END) AS september_customers,
    SUM(CASE WHEN month_start = CONVERT(date, '20050901', 112) THEN default_next_month ELSE 0 END)
        AS september_default_cases
FROM status_sequence;
-- Expected: 180000 | 150000 | 30000 | 6636.
GO
