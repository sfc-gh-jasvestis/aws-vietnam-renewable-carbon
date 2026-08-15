-- ============================================================================
-- Carbon Credit Trading
-- Carbon Credit Trading for Vietnam - ML.FORECAST and Dynamic Tables power real-time carbon credit trading intelligence for renewable energy in Ho Chi Minh City.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS CARBON_TRADING;
CREATE WAREHOUSE IF NOT EXISTS CARBON_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE CARBON_TRADING;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE CARBON_WH;
