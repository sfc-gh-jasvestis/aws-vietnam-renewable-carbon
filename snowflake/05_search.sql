-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Carbon Credit Trading
-- ============================================================================
USE DATABASE CARBON_TRADING;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.CARBON_TRADING_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, CATEGORY
  WAREHOUSE = CARBON_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.DOCUMENTS
);
