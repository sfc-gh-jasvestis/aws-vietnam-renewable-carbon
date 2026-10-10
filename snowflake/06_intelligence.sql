-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-telemetry alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TELEMETRY.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic outage-response knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.OUTAGE_SOP_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.ROOT_CAUSE, s.CATEGORY
  FROM RAW.PLANT_DAILY r JOIN RAW.PLANTS s ON s.ID = r.ENTITY_ID
  WHERE r.ROOT_CAUSE IS NOT NULL AND r.OUTAGE_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ROOT_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ROOT_CAUSE,
  CATEGORY || ' - ' || ROOT_CAUSE || ' outage response' AS TITLE,
  'Synthetic demo SOP. Plant type: ' || CATEGORY || '. Outage cause: ' || ROOT_CAUSE || '. '
  || 'Step 1: notify the plant operations lead, log the outage in the plant event register and record the time generation stopped. '
  || 'Step 2: ' || CASE
       WHEN ROOT_CAUSE ILIKE '%inverter%' OR ROOT_CAUSE ILIKE '%converter%' THEN 'isolate the affected unit, check cooling fans, filters and ambient temperature, and restart only after the power-conversion temperature is back below 60 C.'
       WHEN ROOT_CAUSE ILIKE '%fuse%' THEN 'isolate the combiner box, measure string currents, replace the failed fuse with a like-for-like part and check the string for insulation faults.'
       WHEN ROOT_CAUSE ILIKE '%tracker%' THEN 'stow the affected tracker rows, check the motor controller and limit switches, and replace the drive if it does not respond.'
       WHEN ROOT_CAUSE ILIKE '%meter communication%' THEN 'check the meter modem and data logger, back-fill missing intervals from the logger and flag the gap in the meter data register.'
       WHEN ROOT_CAUSE ILIKE '%gearbox%' THEN 'stop the turbine, sample the gearbox oil, check the oil cooler and inspect the bearings before restart.'
       WHEN ROOT_CAUSE ILIKE '%pitch%' OR ROOT_CAUSE ILIKE '%yaw%' THEN 'put the turbine in safe mode, check the drive motors, encoders and hydraulic pressure, and replace failed parts before restart.'
       WHEN ROOT_CAUSE ILIKE '%debris%' THEN 'reduce flow, clear the trash rack with the rake and inspect the intake screen before restoring full flow.'
       WHEN ROOT_CAUSE ILIKE '%governor%' THEN 'switch the unit to manual control, check the governor oil pressure and speed sensor, and run a load test before return to service.'
       WHEN ROOT_CAUSE ILIKE '%grid%' OR ROOT_CAUSE ILIKE '%transmission%' THEN 'confirm the disconnection with the grid operator control room, keep the plant in a safe state and resynchronise only when the operator gives clearance.'
       ELSE 'record the issue, make the equipment safe and escalate to the regional operations lead.'
     END
  || ' Step 3: if power-conversion temperature stays above 75 C or output stays below 40% of potential after restart, keep the plant on the watch list. '
  || 'Step 4: confirm that meter intervals for the outage window are complete and record the root cause in the plant event register.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.OUTAGE_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ROOT_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ROOT_CAUSE, CONTENT FROM SEARCH.OUTAGE_SOP_DOCS);

-- ---------- Equipment temperature anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.TEMP_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, EQUIP_TEMP_C::FLOAT AS EQUIP_TEMP
FROM RAW.PLANT_DAILY;
CREATE OR REPLACE VIEW ML.TEMP_TRAIN AS
SELECT * FROM ML.TEMP_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TEMP_SERIES);
CREATE OR REPLACE VIEW ML.TEMP_DETECT AS
SELECT * FROM ML.TEMP_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.TEMP_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.TEMP_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TEMP_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'EQUIP_TEMP',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.TEMP_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS EQUIP_TEMP, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.TEMP_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.TEMP_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'EQUIP_TEMP'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.RENEWABLE_ANALYTICS
  TABLES (
    sites AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'plants', 'power plants', 'generation assets')
      COMMENT = 'One row per renewable power plant (entity), 90-day totals',
    risk AS ML.OUTAGE_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day forced outage probability per plant',
    causes AS CURATED.OUTAGE_CAUSES PRIMARY KEY (ROOT_CAUSE)
      COMMENT = 'Forced generation outages by root cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Portfolio-wide totals per day'
  )
  RELATIONSHIPS (risk_site AS risk (ENTITY_ID) REFERENCES sites)
  FACTS (
    sites.intervals_valid_f AS INTERVALS_VALID,
    sites.meter_intervals_f AS METER_INTERVALS,
    sites.generation_mwh_f AS GENERATION_MWH,
    sites.avoided_tco2e_f AS AVOIDED_TCO2E,
    sites.grievances_f AS GRIEVANCES,
    sites.outages_f AS OUTAGE_COUNT,
    sites.downtime_hours_f AS DOWNTIME_HOURS,
    sites.operating_hours_f AS OPERATING_HOURS,
    sites.planned_hours_f AS PLANNED_HOURS,
    risk.outage_prob_f AS OUTAGE_PROB_7D,
    causes.cause_outages_f AS OUTAGE_COUNT,
    causes.cause_invalid_f AS INTERVALS_INVALID,
    causes.cause_hours_f AS DOWNTIME_HOURS,
    daily.day_valid_f AS INTERVALS_VALID,
    daily.day_intervals_f AS METER_INTERVALS,
    daily.day_avoided_f AS AVOIDED_TCO2E,
    daily.day_outages_f AS OUTAGE_COUNT
  )
  DIMENSIONS (
    sites.site_id AS ENTITY_ID WITH SYNONYMS = ('plant', 'entity', 'entity id', 'plant id'),
    sites.site_name AS ENTITY_NAME,
    sites.region_name AS REGION WITH SYNONYMS = ('city', 'region', 'location') COMMENT = 'Vietnamese city used as a region label',
    sites.site_type AS CATEGORY WITH SYNONYMS = ('plant type', 'technology', 'category'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.root_cause AS ROOT_CAUSE,
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    sites.site_count AS COUNT(sites.site_id) WITH SYNONYMS = ('number of entities', 'entity count', 'number of plants'),
    sites.meter_data_valid_pct AS 100 * SUM(sites.intervals_valid_f) / NULLIF(SUM(sites.meter_intervals_f), 0)
      WITH SYNONYMS = ('meter data quality', 'valid meter intervals') COMMENT = 'Meter intervals passing the internal data-quality check / meter intervals',
    sites.total_outages AS SUM(sites.outages_f) WITH SYNONYMS = ('outages', 'forced outages', 'generation outages'),
    sites.avoided_kg_per_mwh AS 1000 * SUM(sites.avoided_tco2e_f) / NULLIF(SUM(sites.generation_mwh_f), 0)
      WITH SYNONYMS = ('avoided emissions per MWh', 'demo emission factor') COMMENT = 'Estimated kg CO2e avoided per MWh, using an internal demo emission factor',
    sites.total_avoided_tco2e AS SUM(sites.avoided_tco2e_f) WITH SYNONYMS = ('avoided emissions', 'estimated avoided emissions')
      COMMENT = 'Estimate only: generation x internal demo emission factor; not a verified or certified figure',
    sites.total_generation_mwh AS SUM(sites.generation_mwh_f) WITH SYNONYMS = ('generation', 'energy generated', 'MWh'),
    sites.total_grievances AS SUM(sites.grievances_f) WITH SYNONYMS = ('grievances', 'community grievances'),
    sites.plant_availability_pct AS 100 * SUM(sites.operating_hours_f) / NULLIF(SUM(sites.planned_hours_f), 0)
      WITH SYNONYMS = ('availability', 'plant availability'),
    sites.total_downtime_hours AS SUM(sites.downtime_hours_f),
    risk.avg_outage_prob AS AVG(risk.outage_prob_f),
    causes.cause_outages AS SUM(causes.cause_outages_f),
    causes.cause_intervals_invalid AS SUM(causes.cause_invalid_f),
    causes.cause_downtime_hours AS SUM(causes.cause_hours_f),
    daily.daily_meter_valid_pct AS 100 * SUM(daily.day_valid_f) / NULLIF(SUM(daily.day_intervals_f), 0),
    daily.daily_avoided_tco2e AS SUM(daily.day_avoided_f),
    daily.daily_outages AS SUM(daily.day_outages_f)
  )
  COMMENT = 'Synthetic Vietnam renewable generation and avoided-emissions analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.RENEWABLE_AGENT
  COMMENT = 'Operations assistant over a synthetic Vietnamese renewable power portfolio'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic, that avoided emissions are estimates from an internal demo emission factor and are not carbon credits or verified figures. Give plant IDs and numbers with units."
  orchestration: "Use renewable_analyst for meter data validity, outages, generation, estimated avoided emissions, grievances, availability, plants, regions, risk and root causes. Use sop_search for outage response procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: renewable_analyst
      description: "Valid meter intervals, forced generation outages, generation in MWh, estimated avoided CO2e, community grievances, plant availability, root causes and outage-risk scores per plant"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic outage-response SOPs by plant type and cause"
tool_resources:
  renewable_analyst:
    semantic_view: __DEMO_DB__.APP.RENEWABLE_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.OUTAGE_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-telemetry alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SITE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, EQUIP_TEMP_C FLOAT, OUTPUT_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION VN_RENEWABLE_CARBON_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALARMS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SITE_ID, EVENT_TS, EQUIP_TEMP_C, OUTPUT_PCT, SOP_HINT)
    SELECT t.SITE_ID, t.EVENT_TS, t.EQUIP_TEMP_C, t.OUTPUT_PCT,
           'Check ' || s.CATEGORY || ' SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TELEMETRY t
    JOIN RAW.PLANTS s ON s.ID = t.SITE_ID
    LEFT JOIN ML.OUTAGE_RISK_SCORES r ON r.ENTITY_ID = t.SITE_ID
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SITE_ID = t.SITE_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('VN_RENEWABLE_CARBON_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Vietnam renewable plant equipment alarm',
      'New live-telemetry alarms logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_ALARM_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TELEMETRY t
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SITE_ID = t.SITE_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALARMS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.OUTAGE_CAUSES REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.OUTAGE_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.OUTAGE_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.OUTAGE_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'AGE_YEARS', AGE_YEARS, 'EQUIP_TEMP_C', EQUIP_TEMP_C,
             'OUTPUT_PCT', OUTPUT_PCT, 'TEMP_7D', TEMP_7D, 'OUTAGES_30D', OUTAGES_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:OUTAGE::FLOAT, 4) AS OUTAGE_PROB_7D,
         CASE WHEN PRED:probability:OUTAGE::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:OUTAGE::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
