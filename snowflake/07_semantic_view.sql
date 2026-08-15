-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Carbon Credit Trading
-- ============================================================================
USE DATABASE CARBON_TRADING;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.CARBON_TRADING_ANALYTICS
  COMMENT = 'Renewable Energy carbon credit trading analytics'
AS
  TABLES (
    CURATED.PERFORMANCE_DASHBOARD AS performance_dashboard,CURATED.TREND_ANALYTICS AS trend_analytics,CURATED.FORECAST_INPUT AS forecast_input,CURATED.OPERATIONAL_RISK AS operational_risk
  );
