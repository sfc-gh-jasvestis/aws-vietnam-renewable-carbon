# Carbon Credit Trading

**Vietnam - Renewable Energy**
Use case: Carbon Credit Trading

> Carbon Credit Trading for Vietnam - ML.FORECAST and Dynamic Tables power real-time carbon credit trading intelligence for renewable energy in Ho Chi Minh City.

## Why Snowflake

Snowflake delivers carbon credit trading intelligence for Vietnamese renewable energy - Dynamic Tables maintain real-time dashboards, ML.FORECAST projects key metrics, and Cortex AI generates recommendations

- **ML.FORECAST for carbon credit trading** - Only demo for Vietnamese renewable energy
- **ML.ANOMALY_DETECTION early warning** - Detects deviations before impact
- **AI recommendations** - Cortex AI actionable guidance
- **Vietnamese context** - Local names, VND economics

## What is deployed

| | |
|---|---|
| Database | `VIETNAM_RENEWABLE_CARBON` |
| Service | `VIETNAM_RENEWABLE_CARBON_APP` |
| Compute pool | `SEA_DEMOS_VIETNAM_POOL` |
| Dimension table | `RAW.CARBON_PROJECTS` (20 rows) |
| Fact table | `RAW.CREDIT_ISSUANCES` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | VND (₫) |

Regions in play: Ho Chi Minh City, Hanoi, Binh Duong, Dong Nai, Can Tho
Segments: Mangrove Restoration, Rice Methane, Cookstove, Reforestation

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh VIETNAM_RENEWABLE_CARBON
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Carbon Credits Issued | `4.2M tCO2e` | total across Carbon Projects |
| Avg Price | `₫84K/tCO2e` | average per event |
| Projects Active | `42` | total across Carbon Projects |
| Revenue (YTD) | `₫354B` | total across Carbon Projects |
| VCM Price Trend | `↑ 24%` | average per event |
| Compliance Demand | `+42%` | average per event |
| Retirement Rate | `67%` | average per event |


## Demo flow

1. Overview
2. Analytics
3. AI Intelligence
4. Ask AI
5. Architecture

## Talking points

- **100K operations** - tracked in Ho Chi Minh City
- **500K metrics** - time-series data points
- **5K assets** - monitored
- **100 docs** - searchable

## Business impact

- Vietnam renewable energy sector growing rapidly (GSO Vietnam)
- AI improves outcomes 15-30% (McKinsey)
- Vietnam FDI strong in this sector (MPI)
- Real-time analytics reduces response 60-80% (Gartner)

---
Generated from `generator/demo_specs/aws-vietnam-renewable-carbon.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-vietnam-renewable-carbon` instead.
