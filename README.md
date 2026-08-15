# Carbon Credit Trading

Carbon Credit Trading for Vietnam - ML.FORECAST and Dynamic Tables power real-time carbon credit trading intelligence for renewable energy in Ho Chi Minh City.

## Architecture

Vietnam renewable energy faces increasing complexity in carbon credit trading. Decision-makers in Ho Chi Minh City need real-time intelligence and ML-powered recommendations.

```mermaid
flowchart LR
    S3[S3 Data Landing] --> SP[Snowpipe]
    SP --> RAW[RAW Tables]
    SPS --> RAW
    RAW --> DT[Dynamic Tables]
    DT --> ML[ML Functions]
    DT --> SEARCH[Cortex Search]
    DT --> SV[Semantic View]
    SV --> AGENT[Cortex Agent]
    SEARCH --> AGENT
    DT --> APP[React App SPCS]
    SM[SageMaker] --> DT
    BR[Bedrock] --> APP
    DT --> QS[QuickSight + Q]
```

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | PERFORMANCE_DASHBOARD / TREND_ANALYTICS / FORECAST_INPUT / OPERATIONAL_RISK |
| ML Functions | ML.FORECAST + ML.ANOMALY_DETECTION |
| Cortex AI | COMPLETE, SUMMARIZE, AI_CLASSIFY |
| Cortex Search | 100 documents indexed |
| Cortex Agent | CARBON_TRADING_AGENT |
| Semantic View | CARBON_TRADING_ANALYTICS |
| React App (SPCS) | 5 tabs + DemoGuide |


## AWS Services

| Service | Role in Demo |
|---------|-------------|
| AWS IoT Core | Ingest real-time data from renewable energy systems |
| Amazon SageMaker | Carbon Credit Trading ML models |
| AWS Glue | ETL and data transformation |
| Apache Iceberg (S3) | Open table format for data sharing |
| Amazon Bedrock (Claude) | Generate carbon credit trading recommendations |
| Amazon QuickSight + Q | Carbon Credit Trading dashboard with NL queries |


## Personas

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Vo Minh Quan** | Head of Carbon Trading | "What are the key carbon credit trading metrics?" "Which areas need attention?" |
| **Tran Thi Ngoc** | Carbon Market Analyst | "Show me the trend analysis." "Which operations are underperforming?" |


## Data

| Table | Rows | Description |
|-------|------|-------------|
| OPERATIONS | 100,000 | Core operational records for carbon credit trading |
| METRICS | 500,000 | Time-series performance metrics |
| ASSETS | 5,000 | Asset and entity master data |
| EVENTS | 200,000 | Operational events and incidents |
| DOCUMENTS | 100 | SOPs, reports, and compliance docs |


## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Cortex AI enabled (ML Functions, Search, Agent)
- Warehouse: CARBON_WH (Medium)
- AWS CLI with access (us-west-2)

### Deployment

```bash
snowsql -f snowflake/00_setup.sql
snowsql -f snowflake/01_marketplace_install.sql
snowsql -f snowflake/02_raw_tables.sql
snowsql -f snowflake/03_staging.sql
snowsql -f snowflake/04_dynamic_tables.sql
snowsql -f snowflake/05_search.sql
snowsql -f snowflake/06_ml_models.sql
snowsql -f snowflake/07_semantic_view.sql
snowsql -f snowflake/08_agent.sql
```

### React App (SPCS)
```bash
cd app && npm ci && npm run build
docker build -t aws-vietnam-renewable-carbon-app .
docker push bdiqc8sm-default.registry.snowflakecomputing.com/carbon_trading/app/aws_vietnam_renewable_carbon/app:latest
```

### Demo Mode
Open the app URL with `?demo=true` for presenter view.

## Build Modes

### Snowflake Only
Run scripts 00-08 (skip AWS-specific integration). Uses:
- **Snowpipe Streaming SDK** instead of AWS IoT Core
- **ML.FORECAST + ML.ANOMALY_DETECTION** instead of Amazon SageMaker
- **Dynamic Tables** instead of AWS Glue
- **Snowflake-managed Iceberg Tables** instead of Apache Iceberg (S3)
- **Cortex Complete** instead of Amazon Bedrock (Claude)
- **Snowflake Intelligence (Cortex Analyst)** instead of Amazon QuickSight + Q

### Full AWS + Snowflake
Run all scripts including AWS integration. Deploy QuickSight dashboard from `quicksight/`.

## Business Impact

Industry research and Snowflake customer outcomes:
- **Vietnam renewable energy sector growing rapidly** — [GSO Vietnam](https://www.gso.gov.vn/)
- **AI improves outcomes 15-30%** — [McKinsey](https://www.mckinsey.com/)
- **Vietnam FDI strong in this sector** — [MPI](https://www.mpi.gov.vn/)
- **Real-time analytics reduces response 60-80%** — [Gartner](https://www.gartner.com/)


## Key Demo Numbers

- **100K operations** tracked in Ho Chi Minh City
- **500K metrics** time-series data points
- **5K assets** monitored
- **100 docs** searchable


## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty.