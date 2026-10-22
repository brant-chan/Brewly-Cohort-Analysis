CREATE OR REPLACE VIEW user_activity AS
SELECT DISTINCT
    u.user_id,
    date_trunc('month', u.signup_date)::DATE  AS cohort_month,
    date_trunc('month', o.order_date)::DATE   AS activity_month,
    datediff('month',
             date_trunc('month', u.signup_date),
             date_trunc('month', o.order_date)) AS month_number
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.status = 'completed'; 

SELECT * FROM user_activity ORDER BY user_id, month_number LIMIT 15;
SELECT MIN(month_number), MAX(month_number) FROM user_activity;
CREATE OR REPLACE TABLE cohort_retention AS
WITH cohort_size AS (                       -- how many signed up each month
    SELECT date_trunc('month', signup_date)::DATE AS cohort_month,
           COUNT(*) AS cohort_users
    FROM users
    GROUP BY 1
),
active AS (                                 -- how many were active each month after
    SELECT cohort_month, month_number,
           COUNT(DISTINCT user_id) AS active_users
    FROM user_activity
    GROUP BY 1, 2
)
SELECT a.cohort_month,
       c.cohort_users,
       a.month_number,
       a.active_users,
       ROUND(100.0 * a.active_users / c.cohort_users, 1) AS retention_pct
FROM active a
JOIN cohort_size c ON a.cohort_month = c.cohort_month
ORDER BY 1, 3;

SELECT * FROM cohort_retention LIMIT 15;
SELECT strftime(cohort_month, '%Y-%m') AS cohort,
       cohort_users,
       MAX(CASE WHEN month_number = 0  THEN retention_pct END) AS m0,
       MAX(CASE WHEN month_number = 1  THEN retention_pct END) AS m1,
       MAX(CASE WHEN month_number = 2  THEN retention_pct END) AS m2,
       MAX(CASE WHEN month_number = 3  THEN retention_pct END) AS m3,
       MAX(CASE WHEN month_number = 4  THEN retention_pct END) AS m4,
       MAX(CASE WHEN month_number = 5  THEN retention_pct END) AS m5,
       MAX(CASE WHEN month_number = 6  THEN retention_pct END) AS m6,
       MAX(CASE WHEN month_number = 7  THEN retention_pct END) AS m7,
       MAX(CASE WHEN month_number = 8  THEN retention_pct END) AS m8,
       MAX(CASE WHEN month_number = 9  THEN retention_pct END) AS m9,
       MAX(CASE WHEN month_number = 10 THEN retention_pct END) AS m10,
       MAX(CASE WHEN month_number = 11 THEN retention_pct END) AS m11
FROM cohort_retention
GROUP BY 1, 2
ORDER BY 1;
WITH base AS (
    SELECT u.user_id, u.acquisition_channel,
           MAX(CASE WHEN a.month_number = 1 THEN 1 ELSE 0 END) AS active_m1,
           MAX(CASE WHEN a.month_number = 3 THEN 1 ELSE 0 END) AS active_m3
    FROM users u LEFT JOIN user_activity a USING (user_id)
    WHERE u.signup_date < DATE '2025-09-01'          -- only cohorts old enough to have an M3
    GROUP BY 1, 2
)
SELECT acquisition_channel, COUNT(*) AS users,
       ROUND(100.0 * AVG(active_m1), 1) AS m1_retention_pct,
       ROUND(100.0 * AVG(active_m3), 1) AS m3_retention_pct
FROM base GROUP BY 1 ORDER BY m3_retention_pct DESC;
--What channel brings the stickiest customers? Which is the worst, by how much?
--The referral is the stickiest and the paid_social is the least stickiest. The referral channel is the stickiest with 63.1% in M1 and 53.9% in M3 and the paid_social is the least with 39.4% in M1 and 19.8% in M3.Paid social performed worse than referrals by 23.7% in M1 and 34.1% in M3
SELECT CASE WHEN cohort_month < DATE '2025-06-01' THEN 'Jan–May cohorts' ELSE 'Jun–Nov cohorts' END AS period,
       ROUND(AVG(retention_pct), 1) AS avg_m1_retention_pct
FROM cohort_retention
WHERE month_number = 1
GROUP BY 1 ORDER BY 1;
--The retention improved greatly in the middle of the year. The channel mix was stable across both periods so it cannot  attributed to aquisition channels.
--Another possiblity for this increase in retention is seasonality, however we only have one year so we need more information.
WITH sizes AS (
    SELECT date_trunc('month', signup_date)::DATE AS cohort_month, COUNT(*) AS cohort_users
    FROM users GROUP BY 1
),
rev AS (
    SELECT date_trunc('month', u.signup_date)::DATE AS cohort_month,
           datediff('month', date_trunc('month', u.signup_date), date_trunc('month', o.order_date)) AS month_number,
           SUM(o.amount) AS revenue
    FROM users u JOIN orders o USING (user_id)
    WHERE o.status = 'completed'
    GROUP BY 1, 2
)
SELECT strftime(cohort_month, '%Y-%m') AS cohort, month_number,
       ROUND(revenue / cohort_users, 2) AS revenue_per_cohort_user
FROM rev JOIN sizes USING (cohort_month)
ORDER BY 1, 2;

CREATE OR REPLACE TABLE revenue_vs_retention AS
WITH cohort_size AS (
    SELECT date_trunc('month', signup_date)::DATE AS cohort_month,
           COUNT(*) AS cohort_users
    FROM users
    GROUP BY 1
),
monthly AS (
    SELECT date_trunc('month', u.signup_date)::DATE AS cohort_month,
           datediff('month', date_trunc('month', u.signup_date),
                             date_trunc('month', o.order_date)) AS month_number,
           COUNT(DISTINCT u.user_id) AS active_users,
           SUM(o.amount)             AS revenue
    FROM users u
    JOIN orders o ON u.user_id = o.user_id
    WHERE o.status = 'completed'
    GROUP BY 1, 2
),
totals AS (
    SELECT m.month_number,
           SUM(c.cohort_users) AS cohort_users,
           SUM(m.active_users) AS active_users,
           SUM(m.revenue)      AS revenue
    FROM monthly m
    JOIN cohort_size c ON m.cohort_month = c.cohort_month
    GROUP BY 1
)
SELECT month_number,
       ROUND(100.0 * active_users / cohort_users, 1) AS retention_pct,
       ROUND(revenue / cohort_users, 2)              AS revenue_per_signup,
       ROUND(100.0 * (active_users / cohort_users)
             / FIRST_VALUE(active_users / cohort_users) OVER (ORDER BY month_number), 0) AS users_pct_of_m0,
       ROUND(100.0 * (revenue / cohort_users)
             / FIRST_VALUE(revenue / cohort_users) OVER (ORDER BY month_number), 0)      AS revenue_pct_of_m0,
       ROUND(revenue / active_users, 2)              AS spend_per_active_user
FROM totals
ORDER BY month_number;

SELECT * FROM revenue_vs_retention;
--Retained customers spent a little more than the first month $44 compare to $42 which will soften the revenue drop after M1. After M1 active customers stay flat around $42 to $46.
--This implies Brewly revenue depends entirely on retaining customers, not on upselling or expansion.
-- Retention by country
WITH base AS (
    SELECT u.user_id,
           u.country,
           MAX(CASE WHEN a.month_number = 1 THEN 1 ELSE 0 END) AS active_m1,
           MAX(CASE WHEN a.month_number = 3 THEN 1 ELSE 0 END) AS active_m3
    FROM users u
    LEFT JOIN user_activity a ON u.user_id = a.user_id
    WHERE u.signup_date < DATE '2025-09-01'
    GROUP BY 1, 2
)
SELECT country,
       COUNT(*)                         AS users,
       ROUND(100.0 * AVG(active_m1), 1) AS m1_retention_pct,
       ROUND(100.0 * AVG(active_m3), 1) AS m3_retention_pct,
       ROUND(196 * SQRT(AVG(active_m3) * (1 - AVG(active_m3)) / COUNT(*)), 1) AS m3_margin_of_error
FROM base
GROUP BY 1
ORDER BY m3_retention_pct DESC;
--The customer contry of origin does not affect the retention.
-- Retention by sign up device
WITH base AS (
    SELECT u.user_id,
           u.signup_device,
           MAX(CASE WHEN a.month_number = 1 THEN 1 ELSE 0 END) AS active_m1,
           MAX(CASE WHEN a.month_number = 3 THEN 1 ELSE 0 END) AS active_m3
    FROM users u
    LEFT JOIN user_activity a ON u.user_id = a.user_id
    WHERE u.signup_date < DATE '2025-09-01'
    GROUP BY 1, 2
)
SELECT signup_device,
       COUNT(*)                         AS users,
       ROUND(100.0 * AVG(active_m1), 1) AS m1_retention_pct,
       ROUND(100.0 * AVG(active_m3), 1) AS m3_retention_pct,
       ROUND(196 * SQRT(AVG(active_m3) * (1 - AVG(active_m3)) / COUNT(*)), 1) AS m3_margin_of_error
FROM base
GROUP BY 1
ORDER BY m3_retention_pct DESC;
--The signup device used does not affect the retention.
