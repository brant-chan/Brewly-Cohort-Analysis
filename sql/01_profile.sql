CREATE OR REPLACE TABLE users AS SELECT * FROM ref_users;
CREATE OR REPLACE TABLE orders AS SELECT * FROM ref_orders;
-- How big is the data?

SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM orders;
-- What time period does it cover?
SELECT MIN(signup_date) AS first_signup, MAX(signup_date) AS last_signup FROM users;
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order  FROM orders;
-- Signups per month (these will be your cohorts)
SELECT date_trunc('month', signup_date) AS signup_month, COUNT(*) AS signups
FROM users GROUP BY 1 ORDER BY 1;
-- Where do customers come from?
SELECT acquisition_channel, COUNT(*) AS users
FROM users GROUP BY 1 ORDER BY 2 DESC;
-- Order statuses
SELECT status, COUNT(*) AS orders
FROM orders GROUP BY 1 ORDER BY 2 DESC;
