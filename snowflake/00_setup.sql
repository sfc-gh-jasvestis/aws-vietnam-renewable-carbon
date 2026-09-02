-- Generated from generator/demo_specs/aws-vietnam-renewable-carbon.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-vietnam-renewable-carbon
-- This is the schema that is actually deployed for VIETNAM_RENEWABLE_CARBON.

-- VIETNAM_RENEWABLE_CARBON  (Carbon Credit Trading)
-- generated from generator/demo_specs/aws-vietnam-renewable-carbon.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS VIETNAM_RENEWABLE_CARBON;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_CARBON.RAW;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_CARBON.CURATED;
CREATE SCHEMA IF NOT EXISTS VIETNAM_RENEWABLE_CARBON.APP;
USE DATABASE VIETNAM_RENEWABLE_CARBON;

-- 5 real regions; entity names carry their region so the two always agree
