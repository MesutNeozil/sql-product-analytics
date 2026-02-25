# SQL Product Analytics Warehouse (PostgreSQL + Python)

## Overview
This project simulates a product analytics workflow for an app/e-commerce product.  
It builds a small analytics warehouse in PostgreSQL from **users**, **events**, and **orders**, then computes core metrics including:
- Daily Active Users (DAU)
- Funnel conversion (view → add_to_cart → purchase)
- Cohort retention (D1 / D7 / D30)
- Sessionization + conversion per session
- Rolling 7-day conversion trend

## Tech Stack
- PostgreSQL (local)
- VS Code + SQLTools
- Python (synthetic data generation + loading)
- Libraries: psycopg2-binary, python-dotenv

## Data Model
Tables:
- `users(user_id, created_at, country, acquisition_channel)`
- `events(event_id, user_id, ts, event_name, device, page)`
- `orders(order_id, user_id, ts, amount)`

Notes:
- Foreign keys enforce integrity (`events.user_id`, `orders.user_id` → `users.user_id`)
- Indexes added for common query patterns (e.g., `(user_id, ts)`)

## How to Run (from scratch)
1. Create tables + indexes:
   - Run `sql/00_schema.sql`
2. (Optional) Insert small seed data:
   - Run `sql/01_seed.sql`
3. Generate and load larger synthetic dataset:
   - Create `.env` (see `.env.example`)
   - Run:
     ```bash
     python src/generate_and_load.py
     ```
4. Create analytics views/models:
   - Run `sql/04_models.sql`
5. Run analysis queries:
   - `sql/02_analytics.sql`
   - `sql/03_quality_checks.sql`

## Key Results

### Acquisition channel conversion (session-level)
![Conversion by acquisition channel](docs/screenshots/channel_conversion.png)

**Takeaway:** Referral converts highest (8.88% per session) and TikTok lowest (4.48%).

### Cohort retention range (D1 / D7)
![Retention min/max](docs/screenshots/retention_summary.png)

**Takeaway:** D1 ranges 0.00–0.75; D7 ranges 0.00–0.1628 (small-cohort and recency effects apply).

### 7-day rolling conversion range
![Rolling conversion min/max](docs/screenshots/rolling_conversion.png)

**Takeaway:** 7-day rolling conversion ranges 0.0422–0.5000; early windows are more volatile due to fewer sessions.
## Data Quality Checks
File: `sql/03_quality_checks.sql`

Checks include:
- Null critical fields
- Duplicate event heuristics
- Negative order amount detection
- Timestamp sanity checks

## Project Structure
sql/
00_schema.sql
01_seed.sql
02_analytics.sql
03_quality_checks.sql
04_models.sql
src/
generate_and_load.py

## What I Learnt
- Designing an analytics-friendly schema with constraints and indexes
- Building reusable SQL models (views) for KPIs and cohort retention
- Sessionization using window functions (LAG + running SUM)
- Generating realistic synthetic data and loading into PostgreSQL for repeatable analysis