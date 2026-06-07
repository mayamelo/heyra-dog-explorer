# heyra-dog-explorer

![Deploy](https://github.com/mayamelo/heyra-dog-explorer/actions/workflows/deploy.yml/badge.svg)


This project started as a technical case study for an interview at Heyra and ended up being a genuinely fun exercise in building a full data pipeline from scratch. The goal was to do a controlled data ingestion from an external source at scheduled intervals, transform its data into easily readable fields and categories, and surface the insights behind them visually.

It also gave me a good excuse to dust off my dbt knowledge, get my hands dirty with GCP for the first time, and revisit a bunch of concepts from my time at Grover.

The source is the [Dog API](https://api.thedogapi.com/v1/breeds) — 628 dog breeds with facts about life span, size, temperament, weight, and height.

---

## Architecture

```
Dog API
   ↓
Cloud Function (Python)          [triggered daily at 02:00 UTC]
   ↓                    ↓
Cloud Storage        BigQuery
(raw JSON,           bronze.dog_api_raw
 partitioned         (schema-on-read)
 by date)
                         ↓
                    dbt (silver layer)           [runs daily at 03:00 UTC]
                    stg_dog_api_breeds
                         ↓
              ┌──────────┼──────────┐
              ↓          ↓          ↓
         dim_breed  fact_weight  dim_temperament
                    _life_span
                         ↓
                   Looker Studio
                         ↓
              Slack alerts (#all-data-pipelines-alerts)
```

**Ingestion:** Cloud Scheduler triggers Cloud Function daily at 02:00 UTC  
**Transformation:** dbt Cloud Production job runs `dbt build` daily at 03:00 UTC (Mon–Fri)  
**CI/CD:** GitHub Actions deploys the Cloud Function on every merge to main  
**Alerting:** Slack notifications on job success, warning, failure, and cancellation  

---

## Tech Stack

| Layer | Tool | Reason |
|---|---|---|
| Ingestion | Cloud Functions (Python 3.11) | Serverless, lightweight, no infrastructure to manage |
| Raw storage | Cloud Storage | Preserves original API response — always reprocessable |
| Warehouse | BigQuery | Serverless, cheap, native Looker Studio integration |
| Transformation | dbt Core (BigQuery adapter) | Version-controlled SQL, dependency management, testing, docs |
| Orchestration | Cloud Scheduler | Managed cron — no server needed for a daily job |
| CI/CD | GitHub Actions | Automated Cloud Function deployment on merge to main |
| Visualisation | Looker Studio | Free, native BigQuery integration, shareable via link |
| Secrets | Secret Manager | Encrypted at rest, IAM-controlled, audit-logged |
| Alerting | Slack via dbt Cloud | Job status notifications routed to #all-data-pipelines-alerts |

---

## Why ELT and not ETL?

The pipeline follows ELT — raw data lands in BigQuery first, untransformed, and dbt handles everything else in-warehouse. The reason is straightforward: storage is cheap, and keeping raw data intact means you can always reprocess if your transformation logic changes. At Grover we often needed to go back to raw data, and in an ETL world that's painful. In ELT it's just another table.

---

## Medallion Architecture

Three layers, each with a clear job:

**Bronze** — raw, untouched. Exactly what the API returned. No transformations, loaded with `autodetect=True`.

**Silver** — cleaned, normalised, type-cast. This is where the messy stuff gets handled — parsing range strings, splitting gender-specific measurements, documenting known nulls.

**Gold** — business-logic layer. Analytics-ready tables with derived fields like `size_class` and `life_span_avg_yrs`, shaped for Looker Studio.

---

## Data Investigation & Quality Findings

Before writing any transformation logic, the raw data was queried directly in BigQuery to understand the actual structure. A few things came up that weren't obvious from the API docs.

### Height and weight fields

The API returns height and weight as nested objects with range strings rather than numbers:

```json
"weight": {
    "imperial": "7-10",
    "metric": "3.2-4.5"
}
```

Some breeds also have gender-specific ranges:
```
"Male: 45-53; Female: 43-53"
```

Confirmed that Male always appears first by checking character positions across all gender-split rows. Female starts at variable positions — making positional extraction unreliable. Used `split(';')` then `split(':')` instead, with a `CASE WHEN` fallback for breeds without gender splits.

### Null analysis

| Column | Nulls / 628 | Decision |
|---|---|---|
| breed_id, breed_name, breed_group, origin, temperament | 0 | Clean — tested with `not_null` |
| bred_for | 628 | Entirely empty — excluded from marts |
| perfect_for | 628 | Entirely empty — excluded from marts |
| life_span_min/max | 40 | Kept in silver, filtered in gold |

Staging is a faithful representation of the source — nulls and all. The mart layer only exposes what's useful.

### Dirty weight data

Two breeds (Langqing, Mongrel) had `"unknown"` as their weight values. Used `safe_cast` throughout `fact_weight_life_span` — they show as `Unknown` in size classification rather than crashing the pipeline.

### Premium API fields

The Dog API docs reference a `family_friendly` score but it's a premium feature not available on the free tier. The dashboard approximates this by filtering on temperament traits associated with family suitability: `friendly`, `gentle`, `affectionate`, `playful`.

---

## dbt Models

### Staging (`silver`)

**`stg_dog_api_breeds`** (view)

Reads from `bronze.dog_api_raw`. Parses life span strings, splits gender-specific measurements, type-casts all fields, excludes entirely-null columns.

### Marts (`gold`)

**`dim_breed`** (table)
One row per breed. Descriptive attributes only — no calculations. Used for filtering and grouping.

**`fact_weight_life_span`** (table)
Numeric analytics. Splits weight ranges into numeric min/max with `safe_cast`. Derives `life_span_avg_yrs` and `size_class` (Small/Medium/Large/Giant/Unknown based on max male weight in kg).

**`dim_temperament`** (table)
One row per breed per temperament trait. Splits the comma-separated temperament string using `unnest(split(...))`. Lowercased for consistent grouping.

### Tests
- `not_null` on breed_id, breed_name, breed_group across staging and marts
- `unique` on breed_id across staging and marts
- `not_null` on life_span_avg_yrs and size_class in fact table
- `accepted_values` on size_class: Small, Medium, Large, Giant, Unknown

---

## Dev / Prod Parameterisation

| Environment | Staging | Marts |
|---|---|---|
| Dev | `silver_dev` | `gold_dev` |
| Prod | `silver` | `gold` |

Handled by a custom `generate_schema_name` macro that overrides dbt's default schema naming. The macro checks `target.schema` at runtime — dev gets `_dev` appended, prod uses the custom schema directly.

---

## Orchestration

**Cloud Scheduler** triggers the Cloud Function daily at **02:00 UTC**.

**dbt Cloud Production job** runs `dbt build` daily at **03:00 UTC** (Monday–Friday), giving ingestion 60 minutes to complete before transformations kick off.

A future improvement would be triggering the dbt job via webhook from the Cloud Function on completion — removing the timing dependency entirely.

---

## Observability & Alerting

**dbt tests** run on every `dbt build` as quality gates:
- Schema tests catch null values and duplicates
- Accepted value tests catch unexpected classifications
- If any test fails, the job fails before downstream models are built

**Slack notifications** are configured via dbt Cloud for the Production Run job, routing alerts to `#all-data-pipelines-alerts` on:
- ✅ Job succeeds
- ⚠️ Job warns
- ❌ Job fails
- 🚫 Job is canceled

**Source freshness** (dbt Core feature) would add a further layer — alerting if `bronze.dog_api_raw` hasn't been updated in more than 25 hours. Currently not supported by dbt Fusion but worth adding when stable.

---

## CI/CD

**`pr.yml`** — runs on every pull request, verifies ingestion files are present  
**`deploy.yml`** — runs on every merge to main, deploys the Cloud Function via `gcloud functions deploy` in ~2 minutes

---

## Security

- Least privilege IAM — the service account has only the permissions the pipeline needs
- Secret Manager for the Dog API key — fetched at runtime, never hardcoded
- GitHub Secrets for the GCP service account key — injected at CI/CD runtime
- Separate runtime and build identities — limits blast radius of a credential leak

---

## Key Findings

- **628 breeds** across all groups
- **Most common traits:** Intelligent (536 breeds), Loyal (451), Alert (376)
- **Longest-living breeds** average ~15 years (Silken Windhound, Miniature Fox Terrier, Koolie)
- **Size distribution:** Large (40%), Medium (33%), Giant (14%), Small (12%)
- **Two breeds** had unknown weight data — handled gracefully with `safe_cast`
- **40 breeds** had no life span data — excluded from gold analytics

---

## Cost

Runs entirely within GCP's free tier. Estimated monthly cost: **$0**.

---

## Project Structure

```
heyra-dog-explorer/
├── ingestion/
│   ├── main.py
│   └── requirements.txt
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── schema.yml
│   │   └── stg_dog_api_breeds.sql
│   └── marts/
│       ├── schema.yml
│       ├── dim_breed.sql
│       ├── dim_temperament.sql
│       └── fact_weight_life_span.sql
├── macros/
│   └── generate_schema_name.sql
├── .github/workflows/
│   ├── pr.yml
│   └── deploy.yml
├── dbt_project.yml
└── README.md
```

---

## Trade-offs & What I'd Do Differently

**Scheduled dbt over webhook trigger** — the dbt prod job runs on a fixed schedule 60 minutes after ingestion. A cleaner approach would be triggering it via webhook from the Cloud Function on completion, removing the timing dependency.

**Family-friendly proxy** — the actual `family_friendly` field is behind a paywall. Used temperament filtering as a proxy — works well enough and is arguably more transparent.

**Source freshness** — dbt Fusion (the version used in dbt Cloud) doesn't yet support source freshness checks. With dbt Core this would add an alerting layer if bronze data goes stale beyond the expected 24 hour window.
