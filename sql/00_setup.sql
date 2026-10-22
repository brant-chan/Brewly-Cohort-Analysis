-- 00_setup.sql — run from the project root:  duckdb brewly.duckdb < sql/00_setup.sql
-- Loads the DIRTY files as all-text staging tables (never trust raw types).
CREATE OR REPLACE TABLE raw_users  AS SELECT * FROM read_csv('data/dirty/users_raw.csv',  all_varchar = true);
CREATE OR REPLACE TABLE raw_orders AS SELECT * FROM read_csv('data/dirty/orders_raw.csv', all_varchar = true);

-- Reference copies of the clean data (for validating your cleaning in Step 3)
CREATE OR REPLACE TABLE ref_users  AS SELECT * FROM read_csv('data/clean/users.csv');
CREATE OR REPLACE TABLE ref_orders AS SELECT * FROM read_csv('data/clean/orders.csv');

SELECT 'raw_users' AS tbl, COUNT(*) AS n FROM raw_users UNION ALL
SELECT 'raw_orders', COUNT(*) FROM raw_orders;
