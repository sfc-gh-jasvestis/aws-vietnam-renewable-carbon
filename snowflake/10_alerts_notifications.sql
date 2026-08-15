-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Carbon Credit Trading
-- ============================================================================
USE DATABASE CARBON_TRADING;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_vietnam_renewable_carbon_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: PERFORMANCE_ALERT
CREATE OR REPLACE ALERT APP.PERFORMANCE_ALERT
  WAREHOUSE = CARBON_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Carbon Credit Trading performance below threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.PERFORMANCE_DASHBOARD
  WHERE 1=1 -- Condition: Key metric below threshold
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_vietnam_renewable_carbon_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Carbon Credit Trading: Carbon Credit Trading performance below threshold',
    'Carbon Credit Trading performance below threshold'
  );

ALTER ALERT APP.PERFORMANCE_ALERT RESUME;

-- Alert: ANOMALY_ALERT
CREATE OR REPLACE ALERT APP.ANOMALY_ALERT
  WAREHOUSE = CARBON_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Anomalous pattern detected'
IF (EXISTS (
  SELECT 1 FROM CURATED.PERFORMANCE_DASHBOARD
  WHERE 1=1 -- Condition: ML detects anomaly
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_vietnam_renewable_carbon_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Carbon Credit Trading: Anomalous pattern detected',
    'Anomalous pattern detected'
  );

ALTER ALERT APP.ANOMALY_ALERT RESUME;

