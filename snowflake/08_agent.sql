-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Carbon Credit Trading
-- ============================================================================
USE DATABASE CARBON_TRADING;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.CARBON_TRADING_AGENT
  COMMENT = 'Carbon Credit Trading AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'CARBON_TRADING.APP.CARBON_TRADING_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'CARBON_TRADING.SEARCH.CARBON_TRADING_SEARCH', TOOL_DESCRIPTION => 'Search documents for Renewable Energy information')
  )
  SYSTEM_PROMPT = 'You are the Carbon Credit Trading Agent for Vietnamese renewable energy operations in Ho Chi Minh City.';
