# Vietnam Renewable Generation and Avoided Emissions

**Vietnam - Solar, Wind and Small Hydro Plants**
Use case: Plant availability, meter data quality, forced-outage risk and estimated avoided emissions

> Plant operations for a fictional renewable power producer with 30 synthetic plants across 4 Vietnamese cities: dynamic tables, a holdout-evaluated outage-risk classifier, an estimated avoided-emissions forecast and grounded AI answers. Avoided emissions use an internal demo emission factor; they are estimates, not verified, certified or carbon-credit figures.

## Why Snowflake

- **Dynamic tables** reconcile meter data valid, outages, generation, estimated avoided CO2e and availability from RAW plant data, with checks in `run_core.py`
- **Outage-risk classification** gives a holdout-evaluated next-7-day forced-outage probability per plant
- **Avoided-emissions forecast** projects 14 days of portfolio-wide estimated t CO2e with prediction intervals
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live telemetry**: a native simulator (Snowflake only) or IoT Core, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.PLANTS` (30 rows) |
| Fact table | `RAW.PLANT_DAILY` (2,700 plant-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `OUTAGE_CAUSES`, `TREND_ANALYSIS` |
| ML | `ML.OUTAGE_RISK_SCORES`, `ML.OUTAGE_RISK_HOLDOUT_METRICS`, `ML.AVOIDED_FORECAST`, `ML.TEMP_ANOMALIES` |

Regions (city labels only): Phan Rang-Thap Cham, Phan Thiet, Bac Lieu, Quy Nhon.
Plant types: Utility Solar, Rooftop Solar, Onshore Wind, Nearshore Wind, Small Hydro.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Meter Data Valid | 93.4% |
| Generation Outages | 370 |
| Total Generation | 883.9 GWh |
| Estimated Avoided Emissions | 566.0 kt CO2e |
| Plant Availability | 97.6% |
| Plants Monitored | 30 |
| Survey Defects Closed | 67.9% |
| Community Grievances | 68 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily meter data valid, invalid meter intervals by outage cause, plant table
2. Predictive: holdout metrics, risk bands, 14-day estimated avoided CO2e forecast, equipment temperature anomalies
3. Plant Health: plant availability, survey defects closed, community grievances, inspection completion against meter data valid, then generate the action memo
4. Live IoT: run `CALL APP.SIMULATE_TELEMETRY(20)` (Snowflake only) or `python aws/publish_telemetry.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_ALARM_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- Per-plant meter data valid ranges from 89.6% to 95.9%. Phan Thiet is the lowest region, at 92.2%, and also has the lowest availability (95.9%).
- Governor faults leave the most meter intervals invalid of the 13 outage causes; PL-0024 has the most outages (48) and the highest outage risk.
- Nearshore wind generates the most energy (371.5 GWh of 883.9 GWh). Avoided emissions are generation times an internal demo factor (640.3 kg CO2e/MWh on average), so present them as an illustration, not a reported or certified figure.
- The risk model is evaluated on a time-based holdout: precision 0.54 and recall 0.55 at 0.5, against a 0.43 base rate. Present it as triage, not a guarantee.
- The Quy Nhon storm grid disconnection and the Phan Thiet transmission line trip are excluded from outage labels, because they are regional grid events, not plant-driven.
- No figure is a compliance finding or a carbon credit; the emission factor and data-quality check are internal to the demo.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
