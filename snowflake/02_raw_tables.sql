-- Synthetic plant-day observations for a fictional renewable power producer in
-- Vietnam. Nothing is seeded as a prediction. Randomness is HASH-seeded, so
-- every rebuild is reproducible: per-plant potential output, asset age and
-- outage propensity, daily weather variation and a cloudy-spell dip,
-- wear between preventive inspections, plant-type-weighted outage causes, and
-- two regional grid events.
-- The emission factor is an internal demo factor, not an official grid
-- emission factor, and avoided emissions are estimates, not carbon credits.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.PLANTS AS
WITH sites AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SITE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 30))
), draws AS (
  SELECT SITE_INDEX,
         MOD(ABS(HASH(SITE_INDEX, 'vnrc-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(SITE_INDEX, 'vnrc-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SITE_INDEX, 'vnrc-insp')), 1000000) / 1e6 AS U_INSP,
         MOD(ABS(HASH(SITE_INDEX, 'vnrc-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SITE_INDEX, 'vnrc-capacity')), 1000000) / 1e6 AS U_CAPACITY
  FROM sites
)
SELECT 'PL-' || LPAD(SITE_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic plant ' || LPAD(SITE_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (7 and 5 are coprime): every region and plant
       -- type is present, with Phan Rang-Thap Cham and Phan Thiet largest.
       -- Cities are region labels only.
       CASE MOD(SITE_INDEX, 7) WHEN 0 THEN 'Phan Rang-Thap Cham' WHEN 1 THEN 'Phan Rang-Thap Cham'
            WHEN 2 THEN 'Phan Thiet' WHEN 3 THEN 'Phan Thiet'
            WHEN 4 THEN 'Bac Lieu' ELSE 'Quy Nhon' END AS REGION,
       CASE MOD(SITE_INDEX, 5) WHEN 0 THEN 'Utility Solar' WHEN 1 THEN 'Rooftop Solar'
            WHEN 2 THEN 'Onshore Wind' WHEN 3 THEN 'Nearshore Wind'
            ELSE 'Small Hydro' END AS CATEGORY,
       SITE_INDEX,
       ROUND(1 + U_AGE * 11, 1) AS AGE_YEARS,
       -- Base daily outage probability 0.6%-3.6%; ~15% of plants are chronic (x3).
       (0.006 + U_RATE * 0.03) * IFF(U_RATE > 0.85, 3, 1) AS BASE_OUTAGE_RATE,
       7 * (1 + FLOOR(U_INSP * 3)) AS INSPECTION_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS INSPECTION_COMPLETION_PROB,
       -- Weather-adjusted potential generation per day (MWh).
       ROUND(CASE MOD(SITE_INDEX, 5) WHEN 0 THEN 420 WHEN 1 THEN 35 WHEN 2 THEN 560
                  WHEN 3 THEN 900 ELSE 260 END * (0.8 + U_CAPACITY * 0.4)) AS DAILY_POTENTIAL_MWH,
       -- Internal demo emission factor (t CO2e avoided per MWh), by region grid node.
       CASE MOD(SITE_INDEX, 7) WHEN 0 THEN 0.66 WHEN 1 THEN 0.66 WHEN 2 THEN 0.64
            WHEN 3 THEN 0.64 WHEN 4 THEN 0.61 ELSE 0.63 END AS EMISSION_FACTOR,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.PLANT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two region-wide grid events in the window (synthetic).
  SELECT * FROM VALUES (31, 'Quy Nhon', 'Storm grid disconnection', 10.0),
                       (68, 'Phan Thiet', 'Transmission line trip', 7.0)
    AS o(DAY_INDEX, REGION, EVENT_CAUSE, HOURS)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.SITE_INDEX, s.CATEGORY, s.REGION, s.AGE_YEARS,
         s.BASE_OUTAGE_RATE, s.INSPECTION_INTERVAL_DAYS, s.INSPECTION_COMPLETION_PROB,
         s.DAILY_POTENTIAL_MWH, s.EMISSION_FACTOR, d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         24.0 AS PLANNED_HOURS,
         MOD(d.DAY_INDEX + s.SITE_INDEX * 5, s.INSPECTION_INTERVAL_DAYS) AS DAYS_SINCE_INSPECTION,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-exc')), 1000000) / 1e6 AS U_EXC,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-down')), 1000000) / 1e6 + 1e-6 AS U_DOWN,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-inspdone')), 1000000) / 1e6 AS U_INSPDONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-weather')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-hit')), 1000000) / 1e6 AS U_HIT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'vnrc-grv')), 1000000) / 1e6 AS U_GRV,
         e.EVENT_CAUSE, e.HOURS AS EVENT_HOURS
  FROM RAW.PLANTS s CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), loaded AS (
  SELECT *,
         IFF(DAYS_SINCE_INSPECTION = 0, 1, 0) AS INSPECTION_DUE,
         IFF(DAYS_SINCE_INSPECTION = 0 AND U_INSPDONE < INSPECTION_COMPLETION_PROB, 1, 0) AS INSPECTION_DONE,
         -- Equipment wear rises between inspections; weak inspection discipline carries wear over.
         DAYS_SINCE_INSPECTION / INSPECTION_INTERVAL_DAYS + (1 - INSPECTION_COMPLETION_PROB) AS WEAR,
         -- Heat stress episode: 8 of every 26 days per plant (staggered).
         IFF(MOD(DAY_INDEX + SITE_INDEX * 11, 26) < 8, 1, 0) AS STRESS,
         -- Generation: daily weather variation and a cloudy spell from day 40 (-35%) easing over 3 days.
         ROUND(DAILY_POTENTIAL_MWH * (0.62 + 0.33 * U_VOLUME)
               * CASE DAY_INDEX - 40 WHEN 0 THEN 0.65 WHEN 1 THEN 0.75 WHEN 2 THEN 0.88 ELSE 1.0 END, 1) AS WEATHER_GEN_MWH
  FROM base
), outages AS (
  SELECT *, WEATHER_GEN_MWH / DAILY_POTENTIAL_MWH AS LOAD_RATIO,
         LEAST(0.5, BASE_OUTAGE_RATE * (0.4 + 1.6 * WEAR) * (0.4 + WEATHER_GEN_MWH / DAILY_POTENTIAL_MWH)
                    * (1 + AGE_YEARS / 20) * (1 + 2.2 * STRESS)) AS P_EXC
  FROM loaded
), counted AS (
  SELECT *,
         CASE WHEN EVENT_HOURS IS NOT NULL THEN 1
              WHEN U_EXC < P_EXC / 4 THEN 2
              WHEN U_EXC < P_EXC THEN 1
              ELSE 0 END AS OUTAGE_COUNT
  FROM outages
)
, timed AS (
  SELECT *,
         -- Forced outage hours: exponential, mean depends on plant type.
         CASE WHEN OUTAGE_COUNT = 0 THEN 0.0
              WHEN EVENT_HOURS IS NOT NULL THEN EVENT_HOURS
              ELSE LEAST(20.0, ROUND(OUTAGE_COUNT * (0.5 - LN(U_DOWN) *
                   CASE CATEGORY WHEN 'Utility Solar' THEN 2.5 WHEN 'Rooftop Solar' THEN 3.5
                                 WHEN 'Onshore Wind' THEN 4.0 WHEN 'Nearshore Wind' THEN 5.0 ELSE 3.0 END), 1))
         END AS DOWNTIME_HOURS,
         -- Share of 15-minute meter intervals that pass the internal data-quality check.
         LEAST(0.998, GREATEST(0.50,
           CASE CATEGORY WHEN 'Utility Solar' THEN 0.975 WHEN 'Rooftop Solar' THEN 0.955
                         WHEN 'Onshore Wind' THEN 0.970 WHEN 'Nearshore Wind' THEN 0.962 ELSE 0.968 END
             - 0.015 * WEAR - 0.006 * U_NOISE
             - OUTAGE_COUNT * (0.05 + 0.10 * U_HIT))) AS VALID_RATE,
         96 AS METER_INTERVALS
  FROM counted
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE, PLANNED_HOURS, DOWNTIME_HOURS,
       PLANNED_HOURS - DOWNTIME_HOURS AS OPERATING_HOURS,
       OUTAGE_COUNT,
       CASE WHEN OUTAGE_COUNT = 0 THEN 'None'
            WHEN EVENT_CAUSE IS NOT NULL THEN EVENT_CAUSE
            WHEN CATEGORY = 'Utility Solar' THEN IFF(U_CAUSE < 0.5, 'Inverter overtemperature trip', IFF(U_CAUSE < 0.8, 'String fuse failure', 'Tracker motor fault'))
            WHEN CATEGORY = 'Rooftop Solar' THEN IFF(U_CAUSE < 0.6, 'Rooftop inverter fault', 'Meter communication loss')
            WHEN CATEGORY = 'Onshore Wind' THEN IFF(U_CAUSE < 0.55, 'Gearbox overtemperature', 'Pitch system fault')
            WHEN CATEGORY = 'Nearshore Wind' THEN IFF(U_CAUSE < 0.6, 'Converter fault', 'Yaw drive fault')
            ELSE IFF(U_CAUSE < 0.6, 'Intake debris blockage', 'Governor fault') END AS ROOT_CAUSE,
       INSPECTION_DUE, INSPECTION_DONE,
       METER_INTERVALS,
       FLOOR(METER_INTERVALS * VALID_RATE) AS INTERVALS_VALID,
       ROUND(WEATHER_GEN_MWH * (PLANNED_HOURS - DOWNTIME_HOURS) / PLANNED_HOURS, 1) AS GENERATION_MWH,
       ROUND(WEATHER_GEN_MWH * (PLANNED_HOURS - DOWNTIME_HOURS) / PLANNED_HOURS * EMISSION_FACTOR, 2) AS AVOIDED_TCO2E,
       IFF(U_GRV < 0.015 + 0.03 * OUTAGE_COUNT + 0.01 * STRESS, 1, 0) AS GRIEVANCES,
       -- Power-conversion equipment temperature (deg C) and output (% of weather-adjusted potential).
       ROUND(42 + 10 * WEAR + 6 * GREATEST(0, LOAD_RATIO - 0.8) + 5 * STRESS + 9 * OUTAGE_COUNT + U_NOISE * 3, 1) AS EQUIP_TEMP_C,
       ROUND(LEAST(100, 100 * LOAD_RATIO * (PLANNED_HOURS - DOWNTIME_HOURS) / PLANNED_HOURS * (0.95 + 0.05 * U_NOISE)), 1) AS OUTPUT_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM timed;

-- Thermography and drone inspection survey progress per plant (snapshot):
-- defects found in the latest survey versus defects closed.
CREATE TABLE RAW.DEFECT_SURVEY AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Utility Solar' THEN 'Module and string thermography' WHEN 'Rooftop Solar' THEN 'Rooftop array walkdown'
                     WHEN 'Onshore Wind' THEN 'Blade and nacelle drone survey' WHEN 'Nearshore Wind' THEN 'Blade and foundation survey'
                     ELSE 'Penstock and powerhouse survey' END AS SURVEY_SCOPE,
       15 + MOD(ABS(HASH(ID, 'vnrc-req')), 56) AS DEFECTS_FOUND,
       FLOOR((15 + MOD(ABS(HASH(ID, 'vnrc-req')), 56)) * (0.50 + MOD(ABS(HASH(ID, 'vnrc-avail')), 1000) / 1000 * 0.45)) AS DEFECTS_CLOSED,
       MOD(ABS(HASH(ID, 'vnrc-order')), 8) AS DEFECTS_SCHEDULED,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.PLANTS;
