-- Create New Relic user
CREATE USER ${username} WITH PASSWORD '${password}';
GRANT SELECT ON pg_stat_database TO ${username};
GRANT SELECT ON pg_stat_database_conflicts TO ${username};
GRANT SELECT ON pg_stat_bgwriter TO ${username};

-- Reset DB
DROP DATABASE IF EXISTS atlas_of_thrones;
CREATE DATABASE atlas_of_thrones;

-- Connect to DB
\c atlas_of_thrones

-- Enable postgis
CREATE EXTENSION postgis;

-- Quit
\q