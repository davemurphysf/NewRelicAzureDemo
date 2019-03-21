-- Create New Relic user
CREATE USER ${nr_username} WITH PASSWORD '${nr_password}';
GRANT SELECT ON pg_stat_database TO ${nr_username};
GRANT SELECT ON pg_stat_database_conflicts TO ${nr_username};
GRANT SELECT ON pg_stat_bgwriter TO ${nr_username};

-- Reset DB
-- DROP DATABASE IF EXISTS atlas_of_thrones;
CREATE DATABASE atlas_of_thrones;

-- Create Application user
CREATE USER ${username} WITH PASSWORD '${password}';
GRANT ALL PRIVILEGES ON atlas_of_thrones TO ${username};

-- Connect to DB
\c atlas_of_thrones

-- Enable postgis
CREATE EXTENSION postgis;

-- Quit
\q
